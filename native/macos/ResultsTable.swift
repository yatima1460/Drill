import SwiftUI

// Capture the path under each press. Streaming can move another file under the pointer
// between clicks, and an open context menu must continue to act on its original file.
private final class NativeResultsTable: NSTableView {
    var rowAtIndex: (Int) -> SearchRow? = { _ in nil }
    var menuForRow: ((SearchRow) -> NSMenu)?
    var openRow: ((SearchRow) -> Void)?
    private var firstClickPath: Data?

    override func menu(for event: NSEvent) -> NSMenu? {
        let index = row(at: convert(event.locationInWindow, from: nil))
        guard let result = rowAtIndex(index) else { return nil }
        selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        return menuForRow?(result)
    }

    override func mouseDown(with event: NSEvent) {
        let index = row(at: convert(event.locationInWindow, from: nil))
        let result = rowAtIndex(index)
        if event.clickCount == 1 { firstClickPath = result?.path }
        super.mouseDown(with: event)
        if event.clickCount == 2, let result, firstClickPath == result.path { openRow?(result) }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: // Return and keypad Enter
            if let result = rowAtIndex(selectedRow) { openRow?(result) }
        case 126 where selectedRow == 0:
            deselectAll(nil)
            window?.makeFirstResponder(window?.initialFirstResponder)
        default: super.keyDown(with: event)
        }
    }
}

private extension SearchRow {
    func hasSameIcon(as other: Self) -> Bool {
        path == other.path && isDirectory == other.isDirectory
    }

    func displaysSameValues(as other: Self) -> Bool {
        hasSameIcon(as: other) && name == other.name && size == other.size && modifiedSeconds == other.modifiedSeconds
    }
}

private struct TableIcon: View {
    let row: SearchRow
    var body: some View { ResultIcon(row: row).id(row.path) }
}

private final class ResultCell: NSTableCellView {
    private var icon: NSHostingView<TableIcon>?

    init(column: ResultColumn, row: SearchRow) {
        super.init(frame: .zero)
        let text = NSTextField(labelWithString: "")
        text.translatesAutoresizingMaskIntoConstraints = false
        text.lineBreakMode = column == .path ? .byTruncatingMiddle : .byTruncatingTail
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(text)
        textField = text
        if column == .name {
            let icon = NSHostingView(rootView: TableIcon(row: row))
            icon.translatesAutoresizingMaskIntoConstraints = false
            addSubview(icon)
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
                icon.centerYAnchor.constraint(equalTo: centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 32),
                icon.heightAnchor.constraint(equalToConstant: 32),
                text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 7),
            ])
            self.icon = icon
        } else {
            text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5).isActive = true
        }
        NSLayoutConstraint.activate([
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
        ])
    }

    required init?(coder: NSCoder) { fatalError("ResultCell is created programmatically") }

    func display(_ row: SearchRow, column: ResultColumn) {
        textField?.stringValue = column.text(for: row)
        toolTip = column == .name || column == .path ? row.displayPath : textField?.stringValue
        if let icon, !icon.rootView.row.hasSameIcon(as: row) { icon.rootView = TableIcon(row: row) }
    }
}

struct ResultsTable: NSViewRepresentable {
    @ObservedObject var model: SearchModel

    func makeCoordinator() -> Coordinator { Coordinator(model) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = NativeResultsTable()
        table.style = .fullWidth
        table.usesAlternatingRowBackgroundColors = true
        table.allowsColumnReordering = false
        table.allowsColumnResizing = true
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.rowHeight = 36
        table.intercellSpacing = .zero
        table.setAccessibilityLabel("Search results")
        table.setAccessibilityIdentifier("search-results")

        for kind in ResultColumn.allCases {
            let column = NSTableColumn(identifier: .init(kind.rawValue))
            column.title = kind.rawValue
            column.sortDescriptorPrototype = NSSortDescriptor(key: kind.rawValue, ascending: true)
            switch kind {
            case .name: column.width = 208; column.minWidth = 80
            case .path: column.width = 223; column.minWidth = 80
            case .size: column.width = 65; column.minWidth = 52
            case .date: column.width = 166; column.minWidth = 90
            }
            column.resizingMask = kind == .name || kind == .path
                ? [.userResizingMask, .autoresizingMask] : [.userResizingMask]
            table.addTableColumn(column)
        }

        let coordinator = context.coordinator
        table.dataSource = coordinator
        table.delegate = coordinator
        table.rowAtIndex = { [weak coordinator] in coordinator?.row(at: $0) }
        table.menuForRow = { ResultActions.menu(for: $0, model: model) }
        table.openRow = { model.open(row: $0) }

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = table
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let table = scroll.documentView as? NSTableView else { return }
        context.coordinator.update(table)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        let model: SearchModel
        private var rows: [SearchRow] = []
        private var revision: UInt?
        private var applying = false

        init(_ model: SearchModel) { self.model = model }

        func row(at index: Int) -> SearchRow? { rows.indices.contains(index) ? rows[index] : nil }
        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

        func update(_ table: NSTableView) {
            applying = true
            defer { applying = false }

            if revision != model.rowsRevision {
                let previous = rows
                rows = model.rows
                revision = model.rowsRevision
                table.noteNumberOfRowsChanged()
                // Keep unchanged visible cells alive, including their asynchronous file icons.
                let visible = table.rows(in: table.visibleRect)
                if visible.length > 0 {
                    let changed = IndexSet((visible.location..<NSMaxRange(visible)).filter {
                        rows.indices.contains($0) && (!previous.indices.contains($0) || !previous[$0].displaysSameValues(as: rows[$0]))
                    })
                    if !changed.isEmpty {
                        table.reloadData(forRowIndexes: changed,
                                         columnIndexes: IndexSet(integersIn: 0..<table.numberOfColumns))
                    }
                }
            }
            let selected = model.selection.flatMap { path in rows.firstIndex { $0.path == path } } ?? -1
            if selected != table.selectedRow {
                if selected >= 0 {
                    table.selectRowIndexes(IndexSet(integer: selected), byExtendingSelection: false)
                    table.scrollRowToVisible(selected)
                } else {
                    table.deselectAll(nil)
                }
            }
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row index: Int) -> NSView? {
            guard let tableColumn, let column = ResultColumn(rawValue: tableColumn.identifier.rawValue),
                  let row = row(at: index) else { return nil }
            let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? ResultCell
                ?? ResultCell(column: column, row: row)
            cell.identifier = tableColumn.identifier
            cell.display(row, column: column)
            return cell
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard let order = tableView.sortDescriptors.first, let key = order.key,
                  let column = ResultColumn(rawValue: key) else { return }
            model.setSort(ResultSort(column: column, ascending: order.ascending))
            update(tableView)
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !applying, let table = notification.object as? NSTableView else { return }
            model.selection = row(at: table.selectedRow)?.path
        }
    }
}
