import SwiftUI

private final class DrillSearchField: NSSearchField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.initialFirstResponder = self
        window.makeFirstResponder(self)
    }
}

private struct SearchField: NSViewRepresentable {
    @ObservedObject var model: SearchModel

    func makeCoordinator() -> Coordinator { Coordinator(model) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = DrillSearchField()
        field.delegate = context.coordinator
        field.placeholderString = "Search files"
        field.setAccessibilityLabel("Search")
        field.setAccessibilityIdentifier("search-field")
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        field.placeholderString = model.mode == .files ? "Search files" : "Search apps"
        if !field.stringValue.utf8.elementsEqual(model.query.utf8) {
            field.stringValue = model.query
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        let model: SearchModel
        init(_ model: SearchModel) { self.model = model }

        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSSearchField {
                model.query = field.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy command: Selector) -> Bool {
            guard !textView.hasMarkedText() else { return false }
            switch command {
            case #selector(NSResponder.moveDown(_:)): model.moveSelection(by: 1)
            case #selector(NSResponder.moveUp(_:)): model.moveSelection(by: -1)
            case #selector(NSResponder.insertNewline(_:)): model.openSelection()
            default: return false
            }
            return true
        }
    }
}

struct SearchView: View {
    @ObservedObject var model: SearchModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SearchField(model: model)
                    .frame(minWidth: 160)
                Picker("Search in", selection: $model.mode) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 125)
                .accessibilityIdentifier("mode-picker")
            }
            .padding(12)

            Divider()
            ResultsTable(model: model)

            Divider()
            HStack {
                Text(model.status)
                    .foregroundStyle(model.validationMessage == nil ? Color.secondary : Color.primary)
                    .accessibilityIdentifier("search-status")
                Spacer()
                if model.canContinue {
                    Button("Continue") { model.resume() }
                        .accessibilityIdentifier("continue")
                }
                Button("Stop") { model.stop() }
                    .disabled(!model.canStop)
                    .accessibilityIdentifier("stop")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .frame(minWidth: 440, minHeight: 290)
    }
}

private final class MainSearchWindow: NSWindow {
    var stopSession: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        // The field editor otherwise consumes Escape before it reaches the window.
        if event.type == .keyDown, event.keyCode == 53, attachedSheet == nil,
           event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
           (firstResponder as? NSTextInputClient)?.hasMarkedText() != true {
            performClose(nil)
            return
        }
        super.sendEvent(event)
    }

    override func close() {
        stopSession?()
        super.close()
    }
}

@MainActor
func makeSearchWindow(model: SearchModel, accessibilityEnabled: Bool = false) -> NSWindow {
    let window = MainSearchWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 470),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
    window.title = "Drill"
    window.stopSession = { model.stop() }
    window.isReleasedWhenClosed = false
    let view = SearchView(model: model)
    if accessibilityEnabled {
        window.contentView = NSHostingView(rootView: view.environment(\.accessibilityEnabled, true))
    } else {
        window.contentView = NSHostingView(rootView: view)
    }
    window.center()
    return window
}
