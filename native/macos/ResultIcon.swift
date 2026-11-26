import SwiftUI

private final class IconRead: Operation, @unchecked Sendable {
    private let path: Data
    private let deliver: @MainActor (CGImage) -> Void

    init(path: Data, deliver: @escaping @MainActor (CGImage) -> Void) {
        self.path = path
        self.deliver = deliver
    }

    override func main() {
        guard !isCancelled else { return }
        var pixels = Data(count: 32 * 32 * 4)
        let decoded = pixels.withUnsafeMutableBytes { output in
            path.withUnsafeBytes { input in
                drill_decode_icon(input.bindMemory(to: UInt8.self).baseAddress, input.count,
                                  output.bindMemory(to: UInt8.self).baseAddress, output.count)
            }
        }
        guard decoded, !isCancelled,
              let provider = CGDataProvider(data: pixels as CFData),
              let image = CGImage(width: 32, height: 32, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true,
                                  intent: .defaultIntent) else { return }
        Task { @MainActor in
            if !self.isCancelled { self.deliver(image) }
        }
    }
}

struct ResultIcon: View {
    let row: SearchRow
    @State private var image: CGImage?
    @State private var read: Operation?
    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Drill embedded icons"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 2).resizable()
            } else {
                Image(systemName: row.isDirectory ? "folder" : "doc")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
        .onAppear { load() }
        .onDisappear {
            read?.cancel()
            read = nil
            image = nil
        }
    }

    private func load() {
        let name = row.name.lowercased()
        guard !row.isDirectory, name.hasSuffix(".exe") || name.hasSuffix(".appimage"),
              read == nil, Self.queue.operationCount < 64 else { return }
        let operation = IconRead(path: row.path) { image = $0 }
        read = operation
        Self.queue.addOperation(operation)
    }
}
