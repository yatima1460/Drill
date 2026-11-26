import AppKit
import CoreFoundation

private struct ActionFailure: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

@MainActor
func checkResultActions() throws {
    func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw ActionFailure(message) }
    }
    func invoke(_ title: String, in menu: NSMenu) throws {
        let index = menu.indexOfItem(withTitle: title)
        guard index >= 0 else { throw ActionFailure("Missing menu command \(title)") }
        menu.performActionForItem(at: index)
    }
    func row(_ bytes: Data, directory: Bool) throws -> SearchRow {
        let url = bytes.withUnsafeBytes { buffer in
            CFURLCreateFromFileSystemRepresentation(nil, buffer.bindMemory(to: UInt8.self).baseAddress,
                                                    buffer.count, directory)
        }
        guard let url else { throw ActionFailure("Could not construct a fixture file URL") }
        let path = String(decoding: bytes, as: UTF8.self)
        return SearchRow(url: url as URL, path: bytes, name: (path as NSString).lastPathComponent,
                         rank: 0, isDirectory: directory, size: directory ? 0 : 3, modifiedSeconds: 1)
    }

    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent("drill-actions-\(UUID())", isDirectory: true)
    let folderURL = root.appendingPathComponent("folder $x; ('ü')", isDirectory: true)
    try manager.createDirectory(at: folderURL, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }
    let fileURL = folderURL.appendingPathComponent("file; 'quote'\n.txt")
    try Data([1, 2, 3]).write(to: fileURL)
    let folder = try row(Data(folderURL.path.utf8), directory: true)
    let file = try row(Data(fileURL.path.utf8), directory: false)

    var opened: [URL] = [], revealed: [URL] = [], appTargets: [URL] = [], chosenApps: [URL] = []
    var errors: [Error] = []
    let model = SearchModel(root: root) { opened.append($0) }
    let editor = root.appendingPathComponent("Editor.app", isDirectory: true)
    let terminal = root.appendingPathComponent("Terminal.app", isDirectory: true)
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    var actions = ResultActions()
    actions.chooseApplication = { editor }
    actions.openWith = { appTargets.append($0); chosenApps.append($1) }
    actions.terminalApplication = { terminal }
    actions.reveal = { revealed.append($0) }
    actions.pasteboard = pasteboard
    actions.presentError = { errors.append($0) }

    let menu = actions.makeMenu(for: file, model: model)
    let titles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)
    try require(titles == ["Open", "Open With…", "Reveal in Finder", "Open Terminal Here",
                           "Copy Full Path", "Copy Date", "Copy Size"], "Unexpected Files commands: \(titles)")
    func renderedIcon(_ image: NSImage) -> Data? {
        let size = NSSize(width: 16, height: 16)
        return NSImage(size: size, flipped: false) { rect in
            image.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
            return true
        }.tiffRepresentation
    }
    for (title, appID) in [("Reveal in Finder", "com.apple.finder"), ("Open Terminal Here", "com.apple.Terminal")] {
        guard let item = menu.item(withTitle: title), let icon = item.image,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appID),
              let expected = renderedIcon(NSWorkspace.shared.icon(forFile: url.path)) else {
            throw ActionFailure("Could not load \(title) and its system application artwork")
        }
        try require(icon.size == NSSize(width: 16, height: 16) && renderedIcon(icon) == expected,
                    "\(title) must show the installed application's artwork")
        try require(item.view == nil && item.isEnabled, "\(title) must use a standard enabled menu row")
        if item.responds(to: NSSelectorFromString("preferredImageVisibility")) {
            try require(item.value(forKey: "preferredImageVisibility") as? Int == 1,
                        "\(title) must request a visible menu image")
            // Give AppKit the actual row on its own so the other icon cannot reserve its image column.
            let index = menu.index(of: item)
            let single = NSMenu()
            menu.removeItem(item)
            single.addItem(item)
            let withIcon = single.size.width
            item.image = nil
            let withoutIcon = single.size.width
            item.image = icon
            single.removeItem(item)
            menu.insertItem(item, at: index)
            try require(withIcon > withoutIcon, "AppKit did not lay out a visible icon for \(title)")
        }
    }

    // Changing selection after the menu opens must leave every command bound to the clicked row.
    model.selection = folder.path
    try invoke("Open", in: menu)
    try invoke("Open With…", in: menu)
    try invoke("Reveal in Finder", in: menu)
    try invoke("Open Terminal Here", in: menu)
    try require(opened == [file.url] && revealed == [file.url], "Open/Reveal targeted a different result")
    try require(appTargets == [file.url, folder.url] && chosenApps == [editor, terminal],
                "The editor needs the exact file URL and Terminal needs its parent")
    for (title, value) in [("Copy Full Path", file.displayPath), ("Copy Date", file.dateText), ("Copy Size", file.sizeText)] {
        try invoke(title, in: menu)
        try require(pasteboard.string(forType: .string) == value, "\(title) didn't copy the displayed value")
    }

    actions.chooseApplication = { nil }
    model.mode = .apps
    let folderMenu = actions.makeMenu(for: folder, model: model)
    try invoke("Launch", in: folderMenu)
    try invoke("Open With…", in: folderMenu)
    try invoke("Open Terminal Here", in: folderMenu)
    try require(opened == [file.url, folder.url] && appTargets == [file.url, folder.url, folder.url]
                && chosenApps == [editor, terminal, terminal], "Launch, canceled chooser or directory Terminal failed")
    model.mode = .files

    let rawFile = try row(folder.path + Data([0x2f, 0xff]), directory: false)
    try invoke("Open Terminal Here", in: actions.makeMenu(for: rawFile, model: model))
    try require(appTargets.last == folder.url && errors.isEmpty, "Could not open parent of a non-UTF-8 filename")

    try manager.removeItem(at: folderURL)
    try invoke("Reveal in Finder", in: menu)
    try invoke("Open Terminal Here", in: menu)
    try require(errors.count == 2 && revealed == [file.url] && appTargets.count == 4,
                "Unavailable targets should report errors without opening another app")
}
