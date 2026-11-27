import AppKit

// AppKit must register ordered windows before it can decide whether to quit.
// Keep them transparent and click-through on the developer's desktop.
@MainActor
func presentPrivateWindow(_ window: NSWindow) {
    window.alphaValue = 0
    window.ignoresMouseEvents = true
    window.orderFront(nil)
}

// Drive a separate instance so the test observes AppKit actually exiting its event loop.
@MainActor
func checkMinimizedPanelQuit() throws {
    let child = Process()
    child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    child.arguments = ["--minimized-panel"]
    let output = Pipe()
    child.standardOutput = output
    try child.run()
    let deadline = ProcessInfo.processInfo.systemUptime + 20
    while child.isRunning && ProcessInfo.processInfo.systemUptime < deadline {
        Thread.sleep(forTimeInterval: 0.05)
    }
    if child.isRunning {
        child.terminate()
        child.waitUntilExit()
        throw WindowFailure("Drill remained running after Escape with a minimized panel")
    }
    let marker = output.fileHandleForReading.readDataToEndOfFile()
    try require(child.terminationReason == .exit && child.terminationStatus == 0 && marker == Data("Escape\n".utf8),
                "Drill must exit successfully after receiving Escape with a minimized panel")
}

@MainActor
func runMinimizedPanelApp() {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    guard app.activationPolicy() == .prohibited else {
        FileHandle.standardError.write(Data("Could not isolate the test application's windows\n".utf8))
        exit(EXIT_FAILURE)
    }
    let delegate = DrillDelegate(root: FileManager.default.temporaryDirectory, present: presentPrivateWindow)
    app.delegate = delegate
    let launched = NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification,
                                                          object: app, queue: .main) { _ in
        Task { @MainActor in
            do { try minimizePanelAndPressEscape() }
            catch {
                FileHandle.standardError.write(Data("Window lifecycle test failed: \(error)\n".utf8))
                exit(EXIT_FAILURE)
            }
        }
    }
    defer { NotificationCenter.default.removeObserver(launched) }
    withExtendedLifetime(delegate) { app.run() }
}

@MainActor
private func minimizePanelAndPressEscape() throws {
    guard let search = NSApp.windows.first(where: { $0.title == "Drill" }),
          let settings = NSApp.mainMenu?.item(withTitle: "Settings")?.submenu,
          let item = settings.item(withTitle: "Interface…") else {
        throw WindowFailure("Missing the search window or Interface menu")
    }
    settings.performActionForItem(at: settings.index(of: item))
    guard let panel = NSApp.windows.first(where: { $0.title == "Interface" }) else {
        throw WindowFailure("Interface did not open")
    }
    try require([search, panel].allSatisfy { $0.alphaValue == 0 && $0.ignoresMouseEvents } && !NSApp.isActive,
                "The lifecycle test windows must remain private")
    panel.miniaturize(nil)
    let driver = WindowDriver(window: search)
    try driver.wait("Interface did not minimize") { panel.isMiniaturized }
    try require(!NSApp.isActive, "Minimizing the panel must keep Drill inactive")
    FileHandle.standardOutput.write(Data("Escape\n".utf8))
    try driver.key("\u{1b}", code: 53)
}
