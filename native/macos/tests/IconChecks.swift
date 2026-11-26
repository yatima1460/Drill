import SwiftUI
import UniformTypeIdentifiers

private struct IconFailure: Error { let message: String }

@MainActor
func exerciseResultIcons() throws {
    let domain = "DrillIconTest-\(UUID())"
    let preferences = UserDefaults(suiteName: domain)!
    defer { preferences.removePersistentDomain(forName: domain) }

    func mount(_ content: some View) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 32, height: 32),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: content.defaultAppStorage(preferences).background(.white))
        return window
    }

    func snapshot(_ window: NSWindow) throws -> Data {
        guard let view = window.contentView,
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
                            isDirectory: directory, size: nil, modifiedSeconds: nil)
        return mount(ResultIcon(row: row))
    }

    @discardableResult
    func wait(_ window: NSWindow, _ message: String, until matches: (Data) -> Bool) throws -> Data {
        let deadline = Date(timeIntervalSinceNow: 5)
        repeat {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.025))
            let rendered = try snapshot(window)
            if matches(rendered) { return rendered }
        } while Date() < deadline
        throw IconFailure(message: message)
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
