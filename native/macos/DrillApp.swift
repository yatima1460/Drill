import SwiftUI

func commandLineRoot(_ path: UnsafePointer<CChar>?) -> URL? {
    guard let path, path.pointee != 0 else { return nil }
    let bytes = UnsafeRawPointer(path).assumingMemoryBound(to: UInt8.self)
    return CFURLCreateFromFileSystemRepresentation(nil, bytes, strlen(path), true) as URL?
}

#if !DRILL_UI_TEST
@main
@MainActor
struct DrillApp {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--version"] {
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            print("Drill \(version as? String ?? "2.0.0")")
            return
        }

        var root: URL?
        if let index = arguments.firstIndex(of: "--root") {
            // The stripped argument index omits argv[0]. Read the original path bytes from argv.
            guard index + 1 < arguments.count,
                  let directory = commandLineRoot(CommandLine.unsafeArgv[index + 2]) else {
                FileHandle.standardError.write(Data("Expected a directory after --root\n".utf8))
                exit(2)
            }
            root = directory
        }
        InterfacePreferences.migrateOnFirstLaunch()
        let app = NSApplication.shared
        let delegate = DrillDelegate(root: root)
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}
#endif

@MainActor
final class DrillDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSWindowDelegate {
    private let model: SearchModel
    private let defaults: UserDefaults
    private let accessibilityEnabled: Bool
    private let present: @MainActor (NSWindow) -> Void
    private var window: NSWindow?
    private var panels: [String: NSWindow] = [:]

    init(root: URL?, defaults: UserDefaults = .standard, accessibilityEnabled: Bool = false,
         present: @escaping @MainActor (NSWindow) -> Void = { $0.makeKeyAndOrderFront(nil) }) {
        model = SearchModel(root: root)
        self.defaults = defaults
        self.accessibilityEnabled = accessibilityEnabled
        self.present = present
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        InterfacePreferences.applyAppearance(from: defaults)
        installMenus()
        let search = makeSearchWindow(model: model)
        search.delegate = self
        window = search
        present(search)
        if NSApp.activationPolicy() == .regular { NSApp.activate(ignoringOtherApps: true) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        for panel in panels.values where panel.isVisible || panel.isMiniaturized { panel.close() }
    }

    @objc private func find(_ sender: Any?) {
        window?.makeKeyAndOrderFront(nil)
        if let field = window?.initialFirstResponder as? NSSearchField {
            window?.makeFirstResponder(field)
            field.selectText(nil)
        }
    }
    @objc private func open(_ sender: Any?) { model.openSelection() }
    @objc private func stop(_ sender: Any?) { model.stop() }
    @objc private func resume(_ sender: Any?) { model.resume() }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(open(_:)): return model.selection != nil
        case #selector(stop(_:)): return model.canStop
        case #selector(resume(_:)): return model.canContinue
        default: return true
        }
    }

    @objc private func showInterface(_ sender: Any?) {
        presentPanel("Interface", size: NSSize(width: 420, height: 270)) { _ in
            InterfaceSettings().defaultAppStorage(defaults)
        }
    }

    @objc private func showPermissions(_ sender: Any?) {
        presentPanel("Permissions", size: NSSize(width: 500, height: 430)) { window in
            PermissionsView(addSearchRoot: model.addSearchRoot, window: { [weak window] in window })
        }
    }

    @objc private func showSyntax(_ sender: Any?) {
        presentPanel("Search syntax", size: NSSize(width: 520, height: 560)) { _ in SyntaxHelp() }
    }

    private func presentPanel<Content: View>(_ title: String, size: NSSize,
                                            @ViewBuilder content: (NSWindow) -> Content) {
        if let window = panels[title] {
            present(window)
            return
        }
        let window = makePanel(title: title, size: size, accessibilityEnabled: accessibilityEnabled, content: content)
        panels[title] = window
        present(window)
    }

    func installMenus() {
        let main = NSMenu()
        func submenu(_ title: String) -> NSMenu {
            let menu = NSMenu(title: title)
            main.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = menu
            return menu
        }
        let app = submenu("Drill")
        app.addItem(withTitle: "About Drill", action: #selector(NSApp.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Drill", action: #selector(NSApp.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Quit Drill", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")

        let file = submenu("File")
        file.addItem(withTitle: "Open Selection", action: #selector(open(_:)), keyEquivalent: "o").target = self
        file.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let edit = submenu("Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let search = submenu("Search")
        search.addItem(withTitle: "Find", action: #selector(find(_:)), keyEquivalent: "f").target = self
        search.addItem(withTitle: "Stop", action: #selector(stop(_:)), keyEquivalent: "").target = self
        search.addItem(withTitle: "Continue", action: #selector(resume(_:)), keyEquivalent: "").target = self

        let settings = submenu("Settings")
        settings.addItem(withTitle: "Interface…", action: #selector(showInterface(_:)), keyEquivalent: ",").target = self
        settings.addItem(withTitle: "Permissions…", action: #selector(showPermissions(_:)), keyEquivalent: "").target = self

        let window = submenu("Window")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = window
        let help = submenu("Help")
        help.addItem(withTitle: "Syntax", action: #selector(showSyntax(_:)), keyEquivalent: "").target = self
        NSApp.helpMenu = help
        NSApp.mainMenu = main
    }
}

@MainActor
func makePanel<Content: View>(title: String, size: NSSize, accessibilityEnabled: Bool = false,
                              @ViewBuilder content: (NSWindow) -> Content) -> NSWindow {
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
    window.title = title
    window.isReleasedWhenClosed = false
    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    scroll.drawsBackground = false
    // The unconstrained intrinsic width of a paragraph is one long line. Measure
    // its wrapped height at the clip view's actual width, including after resize.
    var heightConstraint: NSLayoutConstraint?
    let view = content(window)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
            heightConstraint?.constant = ceil(height)
        }
    let document: NSView
    if accessibilityEnabled {
        document = NSHostingView(rootView: view.environment(\.accessibilityEnabled, true))
    } else {
        document = NSHostingView(rootView: view)
    }
    scroll.documentView = document
    document.translatesAutoresizingMaskIntoConstraints = false
    heightConstraint = document.heightAnchor.constraint(equalToConstant: document.fittingSize.height)
    heightConstraint?.isActive = true

    let close = NSButton(title: "Close", target: window, action: #selector(NSWindow.performClose(_:)))
    close.bezelStyle = .rounded
    close.keyEquivalent = "\u{1b}"
    let canvas = NSView()
    window.contentView = canvas
    for subview in [scroll, close] {
        subview.translatesAutoresizingMaskIntoConstraints = false
        canvas.addSubview(subview)
    }
    NSLayoutConstraint.activate([
        document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
        document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        scroll.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
        scroll.topAnchor.constraint(equalTo: canvas.topAnchor),
        scroll.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
        close.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 10),
        close.trailingAnchor.constraint(equalTo: canvas.trailingAnchor, constant: -14),
        close.bottomAnchor.constraint(equalTo: canvas.bottomAnchor, constant: -12),
    ])
    window.initialFirstResponder = close
    window.contentMinSize = NSSize(width: min(400, size.width), height: min(250, size.height))
    window.center()
    return window
}
