import Foundation

func exercisePreferenceMigration() throws {
    let domain = "drill-migration-test-\(UUID())"
    guard let defaults = UserDefaults(suiteName: domain) else { throw WindowFailure("Missing test defaults") }
    let file = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(domain)
    defer {
        defaults.removePersistentDomain(forName: domain)
        try? FileManager.default.removeItem(at: file)
    }
    let released = #"""
    {
        "window": "(inner_size_points:Some((900.0,600.0)),maximized:false)",
        "embedded_appimage_icons": "false",
        "appearance": "System",
        "embedded_exe_icons": "false",
    }
    """#
    try Data(released.utf8).write(to: file)
    func migrate(_ preview: [String: Any]) {
        InterfacePreferences.migrate(defaults: defaults, domain: domain, preview: preview, legacyFile: file)
    }
    migrate([:])
    var values = defaults.persistentDomain(forName: domain) ?? [:]
    try require(values["appearance"] as? String == "Auto" && values["showExeIcons"] as? Bool == false
                && values["showAppImageIcons"] as? Bool == false && values["window"] == nil,
                "Released settings must preserve both icon opt-outs and system appearance")

    defaults.removePersistentDomain(forName: domain)
    defaults.set("Dark", forKey: "appearance")
    migrate(["appearance": "Light", "showExeIcons": true, "showAppImageIcons": "invalid", "zoom": 3])
    values = defaults.persistentDomain(forName: domain) ?? [:]
    try require(values["appearance"] as? String == "Dark" && values["showExeIcons"] as? Bool == true
                && values["showAppImageIcons"] as? Bool == false && values["zoom"] == nil,
                "Existing settings win, then explicit preview choices, then valid released values")
    defaults.removeObject(forKey: "showExeIcons")
    migrate([:])
    try require(defaults.persistentDomain(forName: domain)?["showExeIcons"] == nil,
                "Subsequent launches must leave preferences alone")

    for invalid in ["{\n    \"embedded_exe_icons\": \"false\",\n", released.replacingOccurrences(of: "900.0", with: String(repeating: "x", count: 65537))] {
        defaults.removePersistentDomain(forName: domain)
        try Data(invalid.utf8).write(to: file)
        migrate([:])
        try require(defaults.persistentDomain(forName: domain)?["showExeIcons"] == nil,
                    "Malformed and oversized released preferences must be ignored")
    }
}
