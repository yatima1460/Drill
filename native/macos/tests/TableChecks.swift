import AppKit

private func tableFailure(_ message: String) -> NSError {
    NSError(domain: "Drill.TableChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}

@MainActor
func resultsTable(in view: NSView) -> NSTableView? {
    if let table = view as? NSTableView { return table }
    return view.subviews.lazy.compactMap { resultsTable(in: $0) }.first
}

// The event queue belongs to this test process. Each event targets the offscreen window,
// so header tracking runs through AppKit without moving the mouse or posting OS input.
@MainActor
private func press(_ view: NSView, from start: NSPoint, to end: NSPoint, count: Int = 1) throws {
    guard let window = view.window else { throw tableFailure("Missing results window") }
    func event(_ type: NSEvent.EventType, _ point: NSPoint) throws -> NSEvent {
        guard let event = NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil),
            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: count, clickCount: count, pressure: type == .leftMouseUp ? 0 : 1)
        else { throw tableFailure("Could not construct an in-window pointer event") }
        return event
    }
    if start != end { NSApp.postEvent(try event(.leftMouseDragged, end), atStart: false) }
    NSApp.postEvent(try event(.leftMouseUp, end), atStart: false)
    view.mouseDown(with: try event(.leftMouseDown, start))
    // Some views track the release inside mouseDown. Others handle it separately.
    if let up = NSApp.nextEvent(matching: .leftMouseUp, until: Date(), inMode: .default, dequeue: true) {
        view.mouseUp(with: up)
    }
}

@MainActor
func checkResultsTable(window: NSWindow, model: SearchModel, opened: () -> [URL]) throws {
    guard let content = window.contentView, let table = resultsTable(in: content),
          let header = table.headerView, table.numberOfRows == 4, model.rows.count == 4,
          table.tableColumns.map(\.title) == ["Name", "Path", "Size", "Date"],
          table.usesAlternatingRowBackgroundColors, table.style == .fullWidth,
          table.allowsColumnResizing, table.tableColumns.allSatisfy({ $0.resizingMask.contains(.userResizingMask) })
    else { throw tableFailure("Expected a striped, resizable four-column results table") }
    try checkAlternatingPixels(table)

    for (index, row) in model.rows.enumerated() {
        let displayed = (0..<4).map {
            (table.view(atColumn: $0, row: index, makeIfNecessary: true) as? NSTableCellView)?.textField?.stringValue
        }
        guard displayed == [row.name, row.parentPath, "Empty", row.dateText], row.dateText != "?"
        else { throw tableFailure("The visible metadata did not match the fixture") }
    }
    let selected = model.rows[1].path
    table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)

    for (index, column) in ResultColumn.allCases.enumerated() {
        let rect = header.headerRect(ofColumn: index)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        for ascending in [true, false] {
            try press(header, from: center, to: center)
            let expected = ResultSort(column: column, ascending: ascending)
            guard model.sort == expected, model.rows.map(\.path) == model.rows.sorted(by: expected.precedes).map(\.path),
                  model.selection == selected, model.rows.indices.contains(table.selectedRow),
                  model.rows[table.selectedRow].path == selected
            else { throw tableFailure("Clicking \(column.rawValue) did not sort and preserve the selected file") }
        }
    }
    let currentSort = model.sort
    let before = table.tableColumns[0].width
    let name = header.headerRect(ofColumn: 0)
    let divider = NSPoint(x: name.maxX - 1, y: name.midY)
    try press(header, from: divider, to: NSPoint(x: divider.x + 30, y: divider.y))
    guard table.tableColumns[0].width >= before + 15, model.sort == currentSort
    else { throw tableFailure("Dragging the Name divider did not resize independently of sorting") }

    func click(_ index: Int, count: Int) throws {
        let cell = table.frameOfCell(atColumn: 0, row: index)
        let point = NSPoint(x: cell.midX, y: cell.midY)
        try press(table, from: point, to: point, count: count)
    }
    let original = model.rows[1]
    let initialOpens = opened()
    table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
    try click(1, count: 1)
    let late = SearchRow(url: URL(fileURLWithPath: "/test/late"), path: Data("/test/late".utf8),
                         name: "late", rank: 0, isDirectory: false, size: 10,
                         modifiedSeconds: (model.rows.compactMap(\.modifiedSeconds).max() ?? 0) + 60)
    model.append([late])
    let deadline = ProcessInfo.processInfo.systemUptime + 3
    while table.numberOfRows != 5 && ProcessInfo.processInfo.systemUptime < deadline {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
    }
    guard table.numberOfRows == 5, table.selectedRow == 2,
          model.selection == original.path, model.rows[2].path == original.path,
          model.rows[0].path == late.path
    else { throw tableFailure("A newly streamed file lost the native table selection or sort order") }
    try click(1, count: 2)
    guard opened() == initialOpens else { throw tableFailure("A moving row opened the file under the second click") }
    let target = model.rows[1].url
    try click(1, count: 1)
    try click(1, count: 2)
    guard opened() == initialOpens + [target] else { throw tableFailure("A double-click did not open its file once") }
    window.makeFirstResponder(window.initialFirstResponder)

    // These late partial/exact hits share their lossy display name. Raw bytes distinguish
    // both paths and produce deterministic ties even on a host that normalizes filenames.
    let folder = Data("/test/".utf8)
    func row(_ suffix: UInt8, size: UInt64, modified: Int64, rank: UInt8 = 1) -> SearchRow {
        let path = folder + [suffix]
        return SearchRow(url: URL(fileURLWithPath: "/test/fixture"), path: path,
                         name: "�", rank: rank, isDirectory: false, size: size, modifiedSeconds: modified)
    }
    let earliest = row(0xfd, size: 0, modified: -1)
    let latest = row(0xff, size: 2_048, modified: 100, rank: 0)
    let middle = row(0xfe, size: 5, modified: 100, rank: 0)
    let stream = SearchModel()
    stream.append([earliest, latest])
    stream.moveSelection(by: 1)
    guard stream.selection == latest.path else { throw tableFailure("Expected the exact match to rank first") }
    stream.setSort(ResultSort(column: .size, ascending: true))
    stream.append([middle])
    guard stream.rows.map(\.path) == [earliest.path, middle.path, latest.path], stream.selection == latest.path,
          stream.rows.map(\.sizeText) == ["Empty", "1 KB", "2 KB"]
    else { throw tableFailure("Late exact matches disrupted numeric size sorting or selection") }
    for column in [ResultColumn.date, .name, .path] {
        stream.setSort(ResultSort(column: column, ascending: false))
        guard stream.rows.map(\.path) == [latest.path, middle.path, earliest.path], stream.selection == latest.path
        else { throw tableFailure("Descending \(column.rawValue) ordering lost the exact path or tie order") }
    }
}

@MainActor
private func checkAlternatingPixels(_ table: NSTableView) throws {
    func failure(_ message: String) -> NSError {
        NSError(domain: "Drill.TableRendering", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    guard table.numberOfRows >= 4, table.numberOfColumns == 4 else {
        throw failure("Rendering the row stripes requires four result rows and columns")
    }
    guard let first = (0..<3).first(where: {
        !table.isRowSelected($0) && !table.isRowSelected($0 + 1)
    }) else { throw failure("Expected adjacent unselected result rows") }

    guard let surface = table.enclosingScrollView else { throw failure("Expected the results scroll view") }
    let previous = surface.appearance
    defer { surface.appearance = previous }
    for name in [NSAppearance.Name.aqua, .darkAqua] {
        surface.appearance = NSAppearance(named: name)
        table.layoutSubtreeIfNeeded()
        table.displayIfNeeded()
        func sample(_ row: Int) throws -> Int {
            // Sample the blank upper padding just inside the Size cell.
            let cell = table.frameOfCell(atColumn: 2, row: row)
            let area = table.convert(NSRect(x: cell.midX, y: cell.minY + 2, width: 3, height: 3), to: surface).integral
            guard let bitmap = surface.bitmapImageRepForCachingDisplay(in: area) else {
                throw failure("Could not allocate the table bitmap in \(name.rawValue)")
            }
            surface.cacheDisplay(in: area, to: bitmap)
            guard let color = bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?
                .usingColorSpace(.sRGB), color.alphaComponent > 0.95 else {
                throw failure("Could not sample an opaque result row in \(name.rawValue)")
            }
            return Int((color.redComponent * 255).rounded())
        }
        // AppKit fades in newly streamed rows. Sample after their stripe becomes visible.
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        var a = try sample(first), b = try sample(first + 1)
        while abs(a - b) < 3 && ProcessInfo.processInfo.systemUptime < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.025))
            a = try sample(first)
            b = try sample(first + 1)
        }
        guard abs(a - b) >= 3 else {
            throw failure("Adjacent result backgrounds matched in \(name.rawValue) (\(a), \(b))")
        }
        print("Rendered adjacent result rows in \(name.rawValue), sRGB red values \(a), \(b)")
    }
}
