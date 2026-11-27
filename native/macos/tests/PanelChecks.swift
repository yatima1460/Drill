import SwiftUI

@MainActor
private func press(_ name: String, in driver: WindowDriver) throws {
    try driver.wait("Missing \(name)") { driver.elements.contains { $0.texts.contains(name) } }
    guard let element = driver.elements.first(where: { $0.texts.contains(name) }), element.press() else {
        throw WindowFailure("Could not press \(name)")
    }
}

@MainActor
func exercisePanels() throws {
    try exercisePreferenceMigration()
    let rootBytes = Array("/tmp/drill-".utf8) + [0xFF]
    let parsed = (rootBytes + [0]).withUnsafeBytes {
        commandLineRoot($0.bindMemory(to: CChar.self).baseAddress)
    }
    let roundTrip = parsed.flatMap { url in
        url.withUnsafeFileSystemRepresentation { path in path.map { Data(bytes: $0, count: strlen($0)) } }
    }
    try require(roundTrip == Data(rootBytes), "--root must retain non-UTF-8 path bytes")
    let suite = "drill-panel-test-\(UUID())"
    guard let defaults = UserDefaults(suiteName: suite) else { throw WindowFailure("Missing test defaults") }
    let originalAppearance = NSApp.appearance
    defer {
        NSApp.appearance = originalAppearance
        defaults.removePersistentDomain(forName: suite)
    }

    let delegate = DrillDelegate(root: nil, defaults: defaults, accessibilityEnabled: true,
                                 present: presentPrivateWindow)
    delegate.installMenus()
    defer { withExtendedLifetime(delegate) {} }

    func openPanel(_ menu: String, _ item: String, title: String) throws -> WindowDriver {
        guard let submenu = NSApp.mainMenu?.item(withTitle: menu)?.submenu,
              let entry = submenu.item(withTitle: item) else { throw WindowFailure("Missing \(menu) > \(item)") }
        submenu.performActionForItem(at: submenu.index(of: entry))
        let windows = NSApp.windows.filter { $0.title == title && $0.isVisible }
        try require(windows.count == 1, "\(item) must open one visible window")
        return WindowDriver(window: windows[0])
    }

    let interface = try openPanel("Settings", "Interface…", title: "Interface")
    defer { interface.window.close() }
    try press("Dark", in: interface)
    try interface.wait("Dark appearance was not applied and saved") {
        NSApp.appearance?.name == .darkAqua && defaults.string(forKey: "appearance") == "Dark"
    }
    try press("Light", in: interface)
    try interface.wait("Light appearance was not applied") { NSApp.appearance?.name == .aqua }
    try press("Auto", in: interface)
    try interface.wait("Auto must follow the system appearance") { NSApp.appearance == nil }

    try press("Show EXE icons", in: interface)
    try interface.wait("EXE icons did not turn off independently") {
        defaults.object(forKey: "showExeIcons") as? Bool == false
            && defaults.object(forKey: "showAppImageIcons") as? Bool != false
    }
    try press("Show AppImage icons", in: interface)
    try press("Show EXE icons", in: interface)
    try interface.wait("The two icon preferences must persist independently") {
        defaults.bool(forKey: "showExeIcons") && defaults.object(forKey: "showAppImageIcons") as? Bool == false
    }

    guard let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                        timestamp: ProcessInfo.processInfo.systemUptime,
                                        windowNumber: interface.window.windowNumber, context: nil,
                                        characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                                        isARepeat: false, keyCode: 53) else {
        throw WindowFailure("Could not construct Escape")
    }
    try require(interface.window.performKeyEquivalent(with: escape), "Interface must handle Escape")
    try interface.wait("Escape did not dismiss Interface") { !interface.window.isVisible }
    let reopened = try openPanel("Settings", "Interface…", title: "Interface")
    try require(reopened.window === interface.window, "Reopening Interface should retain its window")

    defaults.set("Dark", forKey: "appearance")
    InterfacePreferences.applyAppearance(from: defaults)
    try require(NSApp.appearance?.name == .darkAqua, "Relaunch must restore the saved appearance")

    let permissions = try openPanel("Settings", "Permissions…", title: "Permissions")
    defer { permissions.window.close() }
    for title in ["Choose Desktop…", "Choose Documents…", "Choose Downloads…", "Choose iCloud Drive…",
                  "Choose another folder…", "Open Files and Folders Settings…", "Open Full Disk Access Settings…"] {
        try permissions.wait("Missing Permissions button \(title)") {
            permissions.elements.contains { $0.isNamed(title, role: .button) }
        }
    }
    try exercisePermissionChoices()

    let syntax = try openPanel("Help", "Syntax", title: "Search syntax")
    defer { syntax.window.close() }
    syntax.window.contentView?.layoutSubtreeIfNeeded()
    guard let scroll = syntax.window.contentView?.subviews.compactMap({ $0 as? NSScrollView }).first,
          let document = scroll.documentView else { throw WindowFailure("Missing syntax scroll view") }
    try syntax.wait("Syntax help must be vertically scrollable") {
        document.frame.height > scroll.contentSize.height
    }
    try require(abs(scroll.documentVisibleRect.minY) < 1, "Syntax should open at the first section")
    document.scrollToVisible(NSRect(x: 0, y: document.bounds.maxY - 1, width: 1, height: 1))
    try require(scroll.documentVisibleRect.minY > 0, "Later syntax sections must be reachable")
    for text in ["project notes", "fuzzy:projecx notes", "glob:page[0-9]?.pdf", #"regex:^IMG_[0-9]{4}\.jpg$"#] {
        try syntax.wait("Missing syntax example \(text)") {
            syntax.elements.contains { $0.texts.contains(text) }
        }
    }
    try syntax.wait("Missing syntax pattern limits") {
        syntax.elements.contains { $0.texts.contains { $0.contains("4,096 bytes") && $0.contains("eight levels") } }
    }
}

@MainActor
private func exercisePermissionChoices() throws {
    let manager = FileManager.default
    let folder = manager.temporaryDirectory.appendingPathComponent("drill-permission-test-\(UUID())", isDirectory: true)
    try manager.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: folder) }

    var roots: [URL] = []
    var selected: URL? = folder
    var destinations: [URL] = []
    let window = makePanel(title: "Permission fixture", size: NSSize(width: 550, height: 600),
                           accessibilityEnabled: true) { window in
        PermissionsView(addSearchRoot: { roots.append($0) }, window: { [weak window] in window },
                        pickFolder: { _, _ in selected })
            .environment(\.openURL, OpenURLAction { url in
                destinations.append(url)
                return .handled
            })
    }
    defer { window.close() }
    let driver = WindowDriver(window: window)
    try press("Choose another folder…", in: driver)
    try driver.wait("Chosen folder did not reach the search roots and listing check") {
        roots == [folder] && driver.elements.contains { $0.texts.contains("Last checked: Can list this folder") }
    }
    selected = folder.appendingPathComponent("missing", isDirectory: true)
    try press("Choose Downloads…", in: driver)
    try driver.wait("Failed folder listing must be reported") {
        driver.elements.contains { $0.texts.contains("Last checked: Unavailable") }
    }
    try press("Open Files and Folders Settings…", in: driver)
    try press("Open Full Disk Access Settings…", in: driver)
    try require(destinations.map(\.absoluteString) == [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_FilesAndFolders",
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
    ], "The permissions buttons must open the corresponding privacy panes")
}
