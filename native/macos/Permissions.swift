import Darwin
import SwiftUI

// Read one entry so a huge folder or a remote volume never causes an entire listing.
func folderListingStatus(_ url: URL) -> String {
    let error: Int32 = url.withUnsafeFileSystemRepresentation { path in
        guard let path else { return EINVAL }
        guard let directory = opendir(path) else { return errno }
        defer { closedir(directory) }
        errno = 0
        return readdir(directory) == nil ? errno : 0
    }
    switch error {
    case 0: return "Can list this folder"
    case EACCES, EPERM: return "Access denied"
    case ENOENT, ENOTDIR: return "Unavailable"
    default: return "Could not list this folder: \(String(cString: strerror(error)))"
    }
}

@MainActor
private func chooseSearchFolder(window: NSWindow, startingDirectory: URL?) async -> URL? {
    let panel = NSOpenPanel()
    panel.message = "Choose a folder for Drill to search"
    panel.prompt = "Choose"
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.directoryURL = startingDirectory
    return await panel.beginSheetModal(for: window) == .OK ? panel.url : nil
}

private enum SearchLocation: String, CaseIterable {
    case desktop = "Desktop", documents = "Documents", downloads = "Downloads"
    case iCloud = "iCloud Drive", other = "Another folder"

    var startingDirectory: URL? {
        let manager = FileManager.default
        switch self {
        case .desktop: return manager.urls(for: .desktopDirectory, in: .userDomainMask).first
        case .documents: return manager.urls(for: .documentDirectory, in: .userDomainMask).first
        case .downloads: return manager.urls(for: .downloadsDirectory, in: .userDomainMask).first
        case .iCloud:
            return manager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        case .other: return nil
        }
    }
}

@MainActor
struct PermissionsView: View {
    let addSearchRoot: (URL) -> Void
    let window: () -> NSWindow?
    var pickFolder: @MainActor (NSWindow, URL?) async -> URL? = chooseSearchFolder

    @Environment(\.openURL) private var openURL
    @State private var picking = false
    @State private var pending: Set<URL> = []
    @State private var checks: [URL: String] = [:]
    @State private var settingsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a folder to include it in searches during this session. macOS may ask for permission to access it.")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(SearchLocation.allCases, id: \.self) { location in
                    Button("Choose \(location == .other ? "another folder" : location.rawValue)…") {
                        choose(location)
                    }
                }
            }
            .disabled(picking)

            if !checks.isEmpty {
                Text("Folder access").font(.headline)
                ForEach(checks.keys.sorted { $0.path < $1.path }, id: \.self) { url in
                    VStack(alignment: .leading) {
                        Text(verbatim: url.path).textSelection(.enabled)
                        Text(checks[url] ?? "").foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
            Text("System Settings").font(.headline)
            Text("To grant Full Disk Access, add or enable Drill in Privacy & Security.")
            Button("Open Files and Folders Settings…") { openSettings("Privacy_FilesAndFolders") }
            Button("Open Full Disk Access Settings…") { openSettings("Privacy_AllFiles") }
            if settingsError { Text("Could not open System Settings.") }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func choose(_ location: SearchLocation) {
        guard !picking, let parent = window() else { return }
        picking = true
        Task {
            let selected = await pickFolder(parent, location.startingDirectory)
            picking = false
            guard let url = selected else { return }
            addSearchRoot(url)
            guard !pending.contains(url) else { return }
            guard pending.count < 4 else {
                checks[url] = "Choose this folder again when the other checks finish."
                return
            }
            pending.insert(url)
            checks[url] = "Checking…"
            let status = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    continuation.resume(returning: folderListingStatus(url))
                }
            }
            pending.remove(url)
            checks[url] = "Last checked: \(status)"
        }
    }

    private func openSettings(_ pane: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(pane)")!
        openURL(url) { accepted in settingsError = !accepted }
    }
}
