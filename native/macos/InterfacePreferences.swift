import SwiftUI

enum InterfacePreferences {
    static let appearanceKey = "appearance"
    static let exeIconsKey = "showExeIcons"
    static let appImageIconsKey = "showAppImageIcons"

    enum Appearance: String, CaseIterable {
        case automatic = "Auto"
        case light = "Light"
        case dark = "Dark"

        @MainActor func apply() {
            switch self {
            case .automatic: NSApp.appearance = nil
            case .light: NSApp.appearance = NSAppearance(named: .aqua)
            case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }

    @MainActor static func applyAppearance(from defaults: UserDefaults) {
        let saved = defaults.string(forKey: appearanceKey) ?? ""
        (Appearance(rawValue: saved) ?? .automatic).apply()
    }
}

struct InterfaceSettings: View {
    @AppStorage(InterfacePreferences.appearanceKey) private var appearance = InterfacePreferences.Appearance.automatic
    @AppStorage(InterfacePreferences.exeIconsKey) private var exeIcons = true
    @AppStorage(InterfacePreferences.appImageIconsKey) private var appImageIcons = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Appearance", selection: $appearance) {
                ForEach(InterfacePreferences.Appearance.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            .onChange(of: appearance) { $0.apply() }

            VStack(alignment: .leading, spacing: 8) {
                Text("Embedded icons").font(.headline)
                Toggle("Show EXE icons", isOn: $exeIcons)
                Toggle("Show AppImage icons", isOn: $appImageIcons)
            }
        }
        .toggleStyle(.checkbox)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
