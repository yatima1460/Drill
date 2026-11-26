import AppKit

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
            guard index + 1 < arguments.count, !arguments[index + 1].isEmpty else {
                FileHandle.standardError.write(Data("Expected a directory after --root\n".utf8))
                exit(2)
            }
            root = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        }
        let app = NSApplication.shared
        let delegate = DrillDelegate(root: root)
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}
#endif

@MainActor
private final class DrillDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let model: SearchModel
    private var window: NSWindow?

    init(root: URL?) { model = SearchModel(root: root) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenus()
        window = makeSearchWindow(model: model)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc private func find(_ sender: Any?) {
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

    private func installMenus() {
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

        let window = submenu("Window")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = window
        NSApp.mainMenu = main
    }
}
