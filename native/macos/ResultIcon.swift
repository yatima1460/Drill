import Darwin
import SwiftUI
import UniformTypeIdentifiers

private struct IconRequest: Equatable {
    let path: Data
    let isDirectory: Bool
    let embeddedExtension: String?
    let enabled: Bool
}

private final class IconRead: Operation, @unchecked Sendable {
    private let request: IconRequest
    private let deliver: @MainActor (CGImage) -> Void

    init(request: IconRequest, deliver: @escaping @MainActor (CGImage) -> Void) {
        self.request = request
        self.deliver = deliver
    }

    override func main() {
        guard !isCancelled else { return }
        let image: CGImage? = autoreleasepool {
            if let ext = request.embeddedExtension {
                if !request.isDirectory, request.enabled, let decoded = embeddedIcon() {
                    return decoded
                }
                // Ask for the file type alone. Icon Services never receives this path.
                let type = request.isDirectory ? UTType.folder : (UTType(filenameExtension: ext) ?? .executable)
                return resultIconBitmap(NSWorkspace.shared.icon(for: type))
            }
            return platformIcon()
        }
        guard let image, !isCancelled else { return }
        Task { @MainActor in
            if !self.isCancelled { self.deliver(image) }
        }
    }

    private func embeddedIcon() -> CGImage? {
        var pixels = Data(count: 32 * 32 * 4)
        let decoded = pixels.withUnsafeMutableBytes { output in
            request.path.withUnsafeBytes { input in
                drill_decode_icon(input.bindMemory(to: UInt8.self).baseAddress, input.count,
                                  output.bindMemory(to: UInt8.self).baseAddress, output.count)
            }
        }
        guard decoded, let provider = CGDataProvider(data: pixels as CFData) else { return nil }
        return CGImage(width: 32, height: 32, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
    }

    private func platformIcon() -> CGImage? {
        // NSString paths cannot represent every POSIX name. Never look up a lossy display path.
        guard let path = String(data: request.path, encoding: .utf8) else { return nil }
        let policy = IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES
        let scope = IOPOL_SCOPE_THREAD
        let previous = getiopolicy_np(policy, scope)
        guard previous >= 0, setiopolicy_np(policy, scope, IOPOL_MATERIALIZE_DATALESS_FILES_OFF) == 0
        else { return nil }
        defer { _ = setiopolicy_np(policy, scope, previous) }

        var info = stat()
        guard lstat(path, &info) == 0, info.st_flags & UInt32(SF_DATALESS) == 0,
              info.st_mode & S_IFMT == S_IFDIR || info.st_mode & S_IFMT == S_IFREG,
              !isCancelled else { return nil }
        return resultIconBitmap(NSWorkspace.shared.icon(forFile: path))
    }
}

func resultIconBitmap(_ image: NSImage) -> CGImage? {
    let side = 64
    guard let bitmap = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                 bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
    image.draw(in: CGRect(x: 0, y: 0, width: side, height: side), from: .zero,
               operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.makeImage()
}

struct ResultIcon: View {
    let row: SearchRow
    @AppStorage("showExeIcons") private var showExeIcons = true
    @AppStorage("showAppImageIcons") private var showAppImageIcons = true
    @State private var result: (request: IconRequest, image: CGImage)?
    @State private var read: Operation?
    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Drill result icons"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private var request: IconRequest {
        let name = row.name.lowercased()
        if name.hasSuffix(".exe") {
            return IconRequest(path: row.path, isDirectory: row.isDirectory,
                               embeddedExtension: "exe", enabled: showExeIcons)
        }
        if name.hasSuffix(".appimage") {
            return IconRequest(path: row.path, isDirectory: row.isDirectory,
                               embeddedExtension: "appimage", enabled: showAppImageIcons)
        }
        return IconRequest(path: row.path, isDirectory: row.isDirectory,
                           embeddedExtension: nil, enabled: false)
    }

    var body: some View {
        let request = self.request
        Group {
            if let result, result.request == request {
                Image(decorative: result.image, scale: 2).resizable()
            } else {
                Image(systemName: row.isDirectory ? "folder" : "doc")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
        .task(id: request) {
            read?.cancel()
            result = nil
            // Only visible rows retry. Recycled rows cancel their queued or in-flight request.
            while !Task.isCancelled && Self.queue.operationCount >= 64 {
                do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
            }
            guard !Task.isCancelled else { return }
            let operation = IconRead(request: request) { result = (request, $0) }
            read = operation
            Self.queue.addOperation(operation)
        }
        .onDisappear {
            read?.cancel()
            read = nil
            result = nil
        }
    }
}
