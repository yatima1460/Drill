import AppKit
import SwiftUI

struct WindowFailure: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw WindowFailure(message) }
}

// AppKit table row proxies implement the attribute API. SwiftUI's virtual nodes
// expose the protocol selectors without formally adopting NSAccessibilityProtocol.
@MainActor
struct AccessibleNode {
    let object: NSObject

    private func read(_ getter: String, _ attribute: NSAccessibility.Attribute) -> Any? {
        let selector = NSSelectorFromString(getter)
        if object.responds(to: selector),
           let value = object.perform(selector)?.takeUnretainedValue() {
            return value
        }
        let legacy = NSSelectorFromString("accessibilityAttributeValue:")
        guard object.responds(to: legacy) else { return nil }
        return object.perform(legacy, with: attribute.rawValue)?.takeUnretainedValue()
    }

    var role: String { read("accessibilityRole", .role) as? String ?? "" }
    var texts: [String] {
        [
            read("accessibilityLabel", .description),
            read("accessibilityTitle", .title),
            read("accessibilityValue", .value),
            read("accessibilityPlaceholderValue", .placeholderValue),
        ].compactMap { $0 as? String }.filter { !$0.isEmpty }
    }

    func isNamed(_ phrase: String, role expectedRole: NSAccessibility.Role) -> Bool {
        role == expectedRole.rawValue && texts.contains { $0.localizedCaseInsensitiveContains(phrase) }
    }

    func press() -> Bool {
        let target = object as AnyObject
        return target.responds(to: #selector(NSAccessibilityProtocol.accessibilityPerformPress))
            && target.accessibilityPerformPress()
    }

    var children: [Self] {
        let children = read("accessibilityChildren", .children) as? [NSObject] ?? []
        return children.map(Self.init)
    }

    var subtree: [Self] { [self] + children.flatMap { $0.subtree } }
}

@MainActor
struct WindowDriver {
    let window: NSWindow

    var elements: [AccessibleNode] {
        window.contentView?.layoutSubtreeIfNeeded()
        return AccessibleNode(object: window).subtree
    }

    func wait(_ description: String, until condition: () -> Bool) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 8
        while !condition() {
            if ProcessInfo.processInfo.systemUptime >= deadline {
                let observed = elements.map { "\($0.role) \($0.texts)" }.joined(separator: "\n")
                throw WindowFailure("\(description)\nAccessibility tree:\n\(observed)")
            }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
        }
    }

    func key(_ text: String, code: UInt16, modifiers: NSEvent.ModifierFlags = []) throws {
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            guard let event = NSEvent.keyEvent(
                with: type, location: .zero, modifierFlags: modifiers,
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, characters: text, charactersIgnoringModifiers: text,
                isARepeat: false, keyCode: code
            ) else { throw WindowFailure("Could not construct a keyboard event for \(text)") }
            window.sendEvent(event)
        }
    }

    func replaceQuery(with letters: [(String, UInt16)]) throws {
        guard let editor = window.firstResponder as? NSTextView, editor.isFieldEditor else {
            throw WindowFailure("The search field must own keyboard focus")
        }
        editor.selectAll(nil)
        for (letter, code) in letters { try key(letter, code: code) }
    }

    func rows() -> [[String]] {
        elements.filter { $0.role == NSAccessibility.Role.row.rawValue }
            .map { $0.subtree.flatMap(\.texts) }
    }
}

@main
@MainActor
private struct WindowInteractionTest {
    static func main() {
        if CommandLine.arguments.dropFirst() == ["--minimized-panel"] {
            runMinimizedPanelApp()
            exit(EXIT_FAILURE)
        }
        do {
            try checkMinimizedPanelQuit()
            try exerciseWindow()
            try checkStreamingBacklog()
            try exerciseResultIcons()
            try exercisePanels()
            print("SwiftUI interaction checks passed for search, the results table, icons, menus and settings")
        } catch {
            FileHandle.standardError.write(Data("SwiftUI window test failed: \(error)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func exerciseWindow() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("drill-ui-\(UUID())", isDirectory: true)
        let folder = root.appendingPathComponent("Fixture files ü", isDirectory: true)
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }

        let oldNames = (1...12).map { "old-\($0).txt" }
        let newNames = (1...4).map { "new-\($0).txt" }
        for name in oldNames + newNames {
            try Data().write(to: folder.appendingPathComponent(name))
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.finishLaunching()
        try checkResultActions()
        var opened: [URL] = []
        // One hit per UI tick makes the in-flight states observable on a tiny real filesystem.
        let model = SearchModel(root: root, pollBatchSize: 1, pageSize: 3) { opened.append($0) }
        model.waitAfterPoll = { _ in try await Task.sleep(nanoseconds: 30_000_000) }
        let window = makeSearchWindow(model: model, accessibilityEnabled: true)
        defer { window.orderOut(nil) }
        let driver = WindowDriver(window: window)
        try driver.wait("Missing the named search field") {
            driver.elements.contains { $0.isNamed("Search", role: .textField) }
        }

        func editableField(in view: NSView) -> NSTextField? {
            if let field = view as? NSTextField, field.isEditable { return field }
            return view.subviews.lazy.compactMap { editableField(in: $0) }.first
        }
        guard let content = window.contentView, let field = editableField(in: content),
              window.makeFirstResponder(field) else { throw WindowFailure("Could not focus the search field") }
        // Both strings are canonically equivalent in Swift, but the second regex
        // character class also matches the ASCII file "e".
        try Data().write(to: folder.appendingPathComponent("e"))
        let composed = "regex:^[\u{e9}]$"
        let decomposed = "regex:^[e\u{301}]$"
        model.query = composed
        try driver.wait("The composed regex must finish with no matches") {
            model.phase == .finished && model.rows.isEmpty && field.stringValue.utf8.elementsEqual(composed.utf8)
        }
        guard let editor = window.firstResponder as? NSTextView, editor.isFieldEditor
        else { throw WindowFailure("Missing the search field editor") }
        editor.selectAll(nil)
        editor.insertText(decomposed, replacementRange: editor.selectedRange())
        try driver.wait("The decomposed regex edit must find the ASCII e") {
            model.phase == .finished && model.rows.map(\.name) == ["e"]
        }
        model.query = composed
        try driver.wait("Changing back must synchronize the exact regex bytes in the search field") {
            model.phase == .finished && model.rows.isEmpty && field.stringValue.utf8.elementsEqual(composed.utf8)
        }

        let oldKeys: [(String, UInt16)] = [("o", 31), ("l", 37), ("d", 2)]
        let newKeys: [(String, UInt16)] = [("n", 45), ("e", 14), ("w", 13)]

        func isPartialOldSearch() -> Bool {
            let rows = driver.rows()
            return model.isSearching && !rows.isEmpty && rows.count < oldNames.count
                && rows.allSatisfy { row in oldNames.contains(where: row.contains) }
        }
        try driver.replaceQuery(with: oldKeys)
        try driver.wait("No old filenames streamed while searching", until: isPartialOldSearch)
        try require(field.stringValue == "old", "Key events did not insert the old query into the field")

        // Replace a scan while additional old results are still queued.
        try driver.replaceQuery(with: newKeys)
        try driver.wait("Replacement did not reach the first page of new results") {
            let rows = driver.rows()
            return model.canContinue && rows.count == 3
                && rows.allSatisfy { row in newNames.contains(where: row.contains) }
        }
        guard let more = driver.elements.first(where: { $0.isNamed("Continue", role: .button) }),
              more.press() else { throw WindowFailure("Could not press the accessible Continue button") }
        try driver.wait("Continue did not finish with exactly the new filenames") {
            let rows = driver.rows()
            return !model.isSearching && rows.count == newNames.count
                && newNames.allSatisfy { name in rows.contains { $0.contains(name) } }
        }
        try require(field.stringValue == "new", "Replacement did not reach the search field")

        // Up from the first row returns to the field. Reach that position, then select row two.
        let up = String(UnicodeScalar(NSUpArrowFunctionKey)!)
        let down = String(UnicodeScalar(NSDownArrowFunctionKey)!)
        for _ in newNames { try driver.key(up, code: 126) }
        try driver.key(down, code: 125)
        try driver.key(down, code: 125)
        guard let secondRow = driver.rows().dropFirst().first,
              let secondName = newNames.first(where: secondRow.contains) else {
            throw WindowFailure("Could not identify the second rendered result")
        }
        try driver.key("\r", code: 36)
        let secondPath = folder.appendingPathComponent(secondName).resolvingSymlinksInPath().path
        try driver.wait("Return did not open the second rendered result exactly once") {
            opened.map { $0.resolvingSymlinksInPath().path } == [secondPath]
        }
        try checkResultsTable(window: window, model: model, opened: { opened })

        try driver.replaceQuery(with: oldKeys)
        try driver.wait("No cancellable search was visible", until: isPartialOldSearch)
        guard let stop = driver.elements.first(where: { $0.isNamed("Stop", role: .button) }),
              stop.press() else { throw WindowFailure("Could not press the accessible Stop button") }
        try driver.wait("Stop did not cancel the active scan") {
            !model.isSearching && !model.canContinue && driver.elements.contains { $0.isNamed("Stopped", role: .staticText) }
        }
        let stopped = driver.rows()
        try require(!stopped.isEmpty && stopped.count < oldNames.count, "Stop must keep the partial results")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        try require(driver.rows() == stopped, "Rows continued changing after Stop")

        // Escape closes the search window from either responder. Stop is a separate command.
        try driver.replaceQuery(with: newKeys)
        try driver.wait("No active search to close from the field") { model.isSearching }
        try checkEscapeCloses(driver, model: model)

        let idle = SearchModel(root: root)
        let other = makeSearchWindow(model: idle, accessibilityEnabled: true)
        let idleDriver = WindowDriver(window: other)
        idle.query = "new"
        try idleDriver.wait("Could not render results before testing Escape with table focus") {
            !idle.isSearching && !idleDriver.rows().isEmpty
        }
        guard let content = other.contentView, let results = resultsTable(in: content),
              other.makeFirstResponder(results), other.firstResponder === results
        else { throw WindowFailure("Could not focus the results table") }
        try checkEscapeCloses(idleDriver, model: idle)
    }

    @MainActor
    private final class CloseWitness: NSObject {
        var didClose = false
        @objc func closed(_ notification: Notification) { didClose = true }
    }

    private static func checkEscapeCloses(_ driver: WindowDriver, model: SearchModel) throws {
        let witness = CloseWitness()
        NotificationCenter.default.addObserver(witness, selector: #selector(CloseWitness.closed(_:)),
                                              name: NSWindow.willCloseNotification, object: driver.window)
        defer { NotificationCenter.default.removeObserver(witness) }
        try driver.key("\u{1b}", code: 53)
        try driver.wait("Escape did not close the window and cancel its search") {
            witness.didClose && !model.isSearching
        }
    }
}
