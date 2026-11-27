import SwiftUI
import UniformTypeIdentifiers

private struct IconFailure: Error { let message: String }

// AppKit chooses which cached cells to reuse. Supply the original name cell on
// the next request to exercise its same-path update deterministically.
@MainActor
private final class ReusingIconTable: NSTableView {
    var nameCell: NSView?

    override func makeView(withIdentifier identifier: NSUserInterfaceItemIdentifier, owner: Any?) -> NSView? {
        nameCell ?? super.makeView(withIdentifier: identifier, owner: owner)
    }
}

@MainActor
func exerciseResultIcons() throws {
    let domain = "DrillIconTest-\(UUID())"
    let preferences = UserDefaults(suiteName: domain)!
    defer { preferences.removePersistentDomain(forName: domain) }

    func mount(_ content: some View) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 32, height: 32),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: content.defaultAppStorage(preferences))
        return window
    }

    func snapshot(_ window: NSWindow, view target: NSView? = nil) throws -> Data {
        guard let view = target ?? window.contentView,
              view.fittingSize == NSSize(width: 32, height: 32) else {
            throw IconFailure(message: "Result icons must occupy 32 × 32 points")
        }
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw IconFailure(message: "Could not allocate an icon snapshot")
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw IconFailure(message: "Could not read the rendered icon")
        }
        return png
    }

    func nativeReference(_ image: NSImage) throws -> Data {
        guard let raster = resultIconBitmap(image) else {
            throw IconFailure(message: "Could not render the native reference artwork")
        }
        let reference = mount(Image(decorative: raster, scale: 2).resizable().frame(width: 32, height: 32))
        return try snapshot(reference)
    }

    func rowWindow(_ path: String, directory: Bool = false) -> NSWindow {
        let url = URL(fileURLWithPath: path, isDirectory: directory)
        let row = SearchRow(url: url, path: Data(url.path.utf8), name: url.lastPathComponent, rank: 0,
                            isDirectory: directory, size: nil, modifiedSeconds: nil, modifiedNanos: 0)
        return mount(ResultIcon(row: row))
    }

    @discardableResult
    func wait(_ window: NSWindow, _ message: String, view: NSView? = nil,
              until matches: (Data) -> Bool) throws -> Data {
        let deadline = Date(timeIntervalSinceNow: 5)
        repeat {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.025))
            let rendered = try snapshot(window, view: view)
            if matches(rendered) { return rendered }
        } while Date() < deadline
        throw IconFailure(message: message)
    }

    // Coalesce the old query's removal and the next query's first result into
    // one table update, preserving the file's exact path while its kind changes.
    let model = SearchModel()
    let coordinator = ResultsTable.Coordinator(model)
    let table = ReusingIconTable(frame: NSRect(x: 0, y: 0, width: 240, height: 48))
    let nameColumn = NSTableColumn(identifier: .init(ResultColumn.name.rawValue))
    table.addTableColumn(nameColumn)
    table.rowHeight = 36
    table.dataSource = coordinator
    table.delegate = coordinator
    let tableWindow = NSWindow(contentRect: table.frame, styleMask: .borderless, backing: .buffered, defer: false)
    tableWindow.contentView = table
    let manager = FileManager.default
    let item = manager.temporaryDirectory.appendingPathComponent("DrillIcon-\(UUID()).exe")
    try Data().write(to: item)
    defer { try? manager.removeItem(at: item) }
    func samePathRow(directory: Bool) -> SearchRow {
        SearchRow(url: item, path: Data(item.path.utf8), name: item.lastPathComponent, rank: 0,
                  isDirectory: directory, size: 0, modifiedSeconds: nil, modifiedNanos: 0)
    }

    model.append([samePathRow(directory: false)])
    coordinator.update(table)
    guard let cell = table.view(atColumn: 0, row: 0, makeIfNecessary: true) as? NSTableCellView,
          let icon = cell.subviews.first(where: { !($0 is NSTextField) }) else {
        throw IconFailure(message: "Missing hosted icon in the result name cell")
    }
    table.nameCell = cell
    let executableType = UTType(filenameExtension: "exe") ?? .executable
    let executableArt = try nativeReference(NSWorkspace.shared.icon(for: executableType))
    try wait(tableWindow, "Expected native executable artwork in the original cell", view: icon) { $0 == executableArt }
    try manager.removeItem(at: item)
    try manager.createDirectory(at: item, withIntermediateDirectories: false)
    model.query = " "
    model.append([samePathRow(directory: true)])
    coordinator.update(table)
    guard table.view(atColumn: 0, row: 0, makeIfNecessary: true) === cell else {
        throw IconFailure(message: "Expected to reuse the existing result name cell")
    }
    let folderArt = try nativeReference(NSWorkspace.shared.icon(for: .folder))
    try wait(tableWindow, "Reused same-path cell retained file artwork after becoming a folder", view: icon) {
        $0 == folderArt
    }

    // Use the installed system app and a repository file. Compare the displayed pixels with
    // this machine's Icon Services artwork, which can differ across macOS versions and themes.
    let document = URL(fileURLWithPath: "Cargo.toml").path
    for (path, directory) in [("/System/Applications/Calculator.app", true), (document, false)] {
        let expected = try nativeReference(NSWorkspace.shared.icon(forFile: path))
        try wait(rowWindow(path, directory: directory), "Missing native artwork for \(path)") { $0 == expected }
    }

    let placeholder = try snapshot(mount(Image(systemName: "doc").foregroundStyle(.secondary)
        .frame(width: 32, height: 32)))
    let fixtures = [("tools/exe-icon-wasm/tests/fixtures/icon-pe32.exe", "exe", "showExeIcons"),
                    ("tools/appimage-icon-wasm/tests/fixtures/linked-png.AppImage", "appimage", "showAppImageIcons")]
    for (path, ext, key) in fixtures {
        let generic = try nativeReference(NSWorkspace.shared.icon(for: UTType(filenameExtension: ext) ?? .executable))
        // Keep the other format disabled throughout to exercise independent preferences.
        preferences.set(false, forKey: ext == "exe" ? "showAppImageIcons" : "showExeIcons")
        preferences.set(false, forKey: key)
        let window = rowWindow(path)
        try wait(window, "Disabled \(ext) preview did not show the generic type icon") { $0 == generic }
        preferences.set(true, forKey: key)
        let embedded = try wait(window, "Enabling \(ext) previews did not update the visible row") {
            $0 != generic && $0 != placeholder
        }
        preferences.set(false, forKey: key)
        try wait(window, "Disabling \(ext) previews did not clear the embedded artwork") { $0 == generic }
        preferences.set(true, forKey: key)
        try wait(window, "Re-enabling \(ext) previews did not restore the same artwork") { $0 == embedded }
    }
}
