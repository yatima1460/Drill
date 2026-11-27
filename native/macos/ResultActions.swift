import AppKit
import CoreFoundation
import UniformTypeIdentifiers

@MainActor
private enum ResultMenuImages {
    static let finder = applicationIcon("com.apple.finder", fallback: "folder")
    static let terminal = applicationIcon("com.apple.Terminal", fallback: "terminal")

    private static func applicationIcon(_ identifier: String, fallback: String) -> NSImage? {
        let workspace = NSWorkspace.shared
        let icon: NSImage?
        if let url = workspace.urlForApplication(withBundleIdentifier: identifier),
           let copy = workspace.icon(forFile: url.path).copy() as? NSImage {
            icon = copy
        } else {
            icon = NSImage(systemSymbolName: fallback, accessibilityDescription: nil)
        }
        icon?.size = NSSize(width: 16, height: 16)
        return icon
    }
}

@MainActor
private final class ResultMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, image menuImage: NSImage? = nil, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke(_:)), keyEquivalent: "")
        target = self
        image = menuImage
        if menuImage != nil && responds(to: NSSelectorFromString("setPreferredImageVisibility:")) {
            // macOS 27 normally hides menu images. Use its public .visible value with older build SDKs too.
            setValue(1, forKey: "preferredImageVisibility")
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("ResultMenuItem is created in code") }

    @objc private func invoke(_ sender: NSMenuItem) { handler() }
}

@MainActor
struct ResultActions {
    var chooseApplication: () -> URL? = {
        let panel = NSOpenPanel()
        panel.title = "Open With"
        panel.prompt = "Open"
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
        return panel.runModal() == .OK ? panel.url : nil
    }
    var openWith: (URL, URL) -> Void = { url, application in
        NSWorkspace.shared.open([url], withApplicationAt: application, configuration: .init()) { _, error in
            if let error { DispatchQueue.main.async { NSApp.presentError(error) } }
        }
    }
    var reveal: (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) }
    var terminalApplication: () -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") }
    var pasteboard: NSPasteboard = .general
    var presentError: (Error) -> Void = { NSApp.presentError($0) }

    static func menu(for row: SearchRow, model: SearchModel) -> NSMenu {
        ResultActions().makeMenu(for: row, model: model)
    }

    func makeMenu(for row: SearchRow, model: SearchModel) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ResultMenuItem(model.mode == .apps ? "Launch" : "Open") {
            model.open(row: row)
        })
        menu.addItem(ResultMenuItem("Open With…") {
            if let application = chooseApplication() { openWith(row.url, application) }
        })
        menu.addItem(ResultMenuItem("Reveal in Finder", image: ResultMenuImages.finder) {
            do {
                // Finder's selection API has no error callback. Check the entry itself, including a dangling link.
                _ = try fileType(at: row.url, followLinks: false)
                reveal(row.url)
            } catch { presentError(error) }
        })
        menu.addItem(ResultMenuItem("Open Terminal Here", image: ResultMenuImages.terminal) {
            do {
                let directory = try terminalDirectory(for: row)
                guard let application = terminalApplication() else {
                    throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError,
                                  userInfo: [NSLocalizedDescriptionKey: "Terminal could not be found."])
                }
                openWith(directory, application)
            } catch { presentError(error) }
        })
        menu.addItem(.separator())
        for (title, value) in [("Copy Full Path", row.displayPath), ("Copy Date", row.dateText), ("Copy Size", row.sizeText)] {
            menu.addItem(ResultMenuItem(title) {
                pasteboard.clearContents()
                if !pasteboard.setString(value, forType: .string) {
                    presentError(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError,
                                         userInfo: [NSLocalizedDescriptionKey: "Could not copy to the clipboard."]))
                }
            })
        }
        return menu
    }

    private func fileType(at url: URL, followLinks: Bool = true) throws -> mode_t {
        try url.withUnsafeFileSystemRepresentation { path in
            guard let path else { throw CocoaError(.fileReadInvalidFileName) }
            var info = stat()
            let status = followLinks ? stat(path, &info) : lstat(path, &info)
            guard status == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO, userInfo: [NSURLErrorKey: url])
            }
            return info.st_mode & S_IFMT
        }
    }

    private func terminalDirectory(for row: SearchRow) throws -> URL {
        var directory = row.url
        if !row.isDirectory && (try? fileType(at: row.url)) != S_IFDIR {
            // URL.deletingLastPathComponent() can return the original file if its name isn't UTF-8.
            let parent = row.parentBytes.withUnsafeBytes { bytes in
                CFURLCreateFromFileSystemRepresentation(nil, bytes.bindMemory(to: UInt8.self).baseAddress,
                                                        bytes.count, true)
            }
            guard let parent, !row.parentBytes.isEmpty else { throw CocoaError(.fileReadInvalidFileName) }
            directory = parent as URL
        }
        guard try fileType(at: directory) == S_IFDIR else { throw POSIXError(.ENOTDIR) }
        return directory
    }
}
