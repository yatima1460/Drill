import Foundation

extension InterfacePreferences {
    static func migrateOnFirstLaunch() {
        let domain = "software.drill"
        guard Bundle.main.bundleIdentifier == domain else { return }
        let defaults = UserDefaults.standard
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        migrate(defaults: defaults, domain: domain,
                preview: defaults.persistentDomain(forName: "software.drill.swift-preview"),
                legacyFile: support?.appendingPathComponent("Drill/app.ron"))
    }

    static func migrate(defaults: UserDefaults, domain: String, preview: @autoclosure () -> [String: Any]?,
                        legacyFile: URL?) {
        let marker = "didMigrateNativeInterfacePreferences"
        let current = defaults.persistentDomain(forName: domain) ?? [:]
        guard current[marker] as? Bool != true else { return }
        let previous = preview() ?? [:]
        let legacy = legacyFile.flatMap(readReleasedPreferences) ?? [:]
        if current[appearanceKey] == nil {
            let released: [String: Appearance] = ["System": .automatic, "Light": .light, "Dark": .dark]
            let appearance = (previous[appearanceKey] as? String).flatMap(Appearance.init(rawValue:))
                ?? legacy["appearance"].flatMap { released[$0] }
            if let appearance { defaults.set(appearance.rawValue, forKey: appearanceKey) }
        }
        for (key, oldKey) in [(exeIconsKey, "embedded_exe_icons"), (appImageIconsKey, "embedded_appimage_icons")]
        where current[key] == nil {
            if let flag = previous[key] as? NSNumber, CFGetTypeID(flag) == CFBooleanGetTypeID() {
                defaults.set(flag.boolValue, forKey: key)
            } else if let value = legacy[oldKey].flatMap(Bool.init) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: marker)
    }

    private static func readReleasedPreferences(_ url: URL) -> [String: String]? {
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW_ANY | O_CLOEXEC)
        guard descriptor >= 0 else { return nil }
        let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        let limit = 64 * 1024
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_size > 0, info.st_size <= limit,
              let bytes = try? file.read(upToCount: limit + 1), bytes.count == info.st_size,
              var text = String(data: bytes, encoding: .utf8), text.hasPrefix("{\n"), text.hasSuffix(",\n}") else {
            return nil
        }
        // eframe's pretty RON string map is JSON for Drill's saved keys except for the final comma.
        text.removeLast(3)
        text.append("}")
        return try? JSONDecoder().decode([String: String].self, from: Data(text.utf8))
    }
}
