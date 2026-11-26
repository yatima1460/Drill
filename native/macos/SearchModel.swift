import AppKit
import Combine
import CoreFoundation

enum SearchMode: String, CaseIterable {
    case files = "Files"
    case apps = "Apps"
}

struct SearchRow: Identifiable {
    var id: URL { url }
    let url: URL
    let path: Data
    let name: String
    let rank: UInt8
    let isDirectory: Bool

    var displayPath: String { String(decoding: path, as: UTF8.self) }
}

// The Rust callback borrows its arguments only until it returns.
private final class HitBatch {
    var rows: [SearchRow] = []

    static let receive: DrillHitCallback = { context, bytes, count, name, rank, isDir, _, _ in
        guard let context, let bytes, let name,
              let url = CFURLCreateFromFileSystemRepresentation(nil, bytes, count, isDir) else {
            return
        }
        let batch = Unmanaged<HitBatch>.fromOpaque(context).takeUnretainedValue()
        // CFURL retains the original bytes, including non-UTF-8 names, through Launch Services.
        batch.rows.append(SearchRow(url: url as URL, path: Data(bytes: bytes, count: count),
                                    name: String(cString: name), rank: rank, isDirectory: isDir))
    }
}

@MainActor
final class SearchModel: ObservableObject {
    enum Phase { case empty, searching, paused, stopped, finished, invalid }

    @Published var query = "" { didSet { if oldValue != query { replaceSearch() } } }
    @Published var mode = SearchMode.files { didSet { if oldValue != mode { replaceSearch() } } }
    @Published var selection: URL?
    @Published private(set) var rows: [SearchRow] = []
    @Published private(set) var phase = Phase.empty
    @Published private(set) var validationMessage: String?

    var isSearching: Bool { phase == .searching }
    var canContinue: Bool { phase == .paused }
    var canStop: Bool { isSearching || canContinue }

    var status: String {
        let count = "\(rows.count) \(rows.count == 1 ? "result" : "results")"
        switch phase {
        case .empty: return "Type to search"
        case .searching: return "Searching · \(count)"
        case .paused: return "\(count) · More results available"
        case .stopped: return "Stopped · \(count)"
        case .finished: return count
        case .invalid: return validationMessage ?? "Invalid query"
        }
    }

    private let root: URL?
    private let openURL: (URL) -> Void
    private let pollBatchSize: UInt32
    private let pageSize: Int
    private var limit: Int
    private var exactCount = 0
    private var lookahead: SearchRow?
    private var handle: OpaquePointer?
    private var polling: Task<Void, Never>?

    init(root: URL? = nil, pollBatchSize: UInt32 = 64, pageSize: Int = 10_000,
         openURL: @escaping (URL) -> Void = { url in
             NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                 if let error { DispatchQueue.main.async { NSApp.presentError(error) } }
             }
         }) {
        self.root = root
        self.openURL = openURL
        self.pollBatchSize = min(max(1, pollBatchSize), 256)
        self.pageSize = max(1, min(pageSize, Int.max - 1))
        self.limit = self.pageSize
    }

    deinit {
        polling?.cancel()
        drill_search_free(handle)
    }

    func openSelection() {
        if let selection { openURL(selection) }
    }

    func moveSelection(by offset: Int) {
        guard !rows.isEmpty else { return }
        let current = selection.flatMap { url in rows.firstIndex { $0.id == url } } ?? -1
        let target = max(-1, min(rows.count - 1, current + offset))
        selection = target < 0 ? nil : rows[target].id
    }

    func stop() {
        guard canStop else { return }
        discardHandle()
        phase = .stopped
    }

    func resume() {
        guard let handle, let lookahead, canContinue else { return }
        self.lookahead = nil
        limit = limit > Int.max - pageSize - 1 ? Int.max - 1 : limit + pageSize
        append([lookahead])
        drill_search_set_paused(handle, false)
        phase = .searching
        schedulePolls(starting: false)
    }

    private func replaceSearch() {
        discardHandle()
        selection = nil
        rows.removeAll()
        exactCount = 0
        limit = pageSize
        validationMessage = nil
        guard !query.utf8.contains(0) else {
            validationMessage = "A search query cannot contain a NUL character."
            phase = .invalid
            return
        }
        if mode == .files && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            phase = .empty
            return
        }
        phase = .searching
        schedulePolls(starting: true)
    }

    private func discardHandle() {
        polling?.cancel()
        polling = nil
        drill_search_free(handle)
        handle = nil
        lookahead = nil
    }

    private func schedulePolls(starting: Bool) {
        polling?.cancel()
        polling = Task { @MainActor [weak self] in
            if starting {
                do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                self?.start()
            }
            while !Task.isCancelled && self?.isSearching == true {
                self?.poll()
                do { try await Task.sleep(nanoseconds: 30_000_000) } catch { return }
            }
        }
    }

    private func start() {
        handle = query.withCString { text in
            if let root {
                return root.withUnsafeFileSystemRepresentation { path in
                    guard let path else { return nil }
                    let bytes = UnsafeRawPointer(path).assumingMemoryBound(to: UInt8.self)
                    return drill_search_start(text, mode == .apps, bytes, strlen(path))
                }
            }
            return drill_search_start(text, mode == .apps, nil, 0)
        }
        if handle == nil {
            validationMessage = "Could not start the search."
            phase = .invalid
        }
    }

    private func poll() {
        guard let handle else { return }
        let batch = HitBatch()
        let maxHits = min(Int(pollBatchSize), limit - rows.count + 1)
        let done = drill_search_poll(handle, UInt32(maxHits),
                                     Unmanaged.passUnretained(batch).toOpaque(), HitBatch.receive)
        if let error = drill_search_error(handle) {
            validationMessage = String(cString: error)
            discardHandle()
            phase = .invalid
            return
        }
        if rows.count + batch.rows.count > limit {
            lookahead = batch.rows.removeLast()
            drill_search_set_paused(handle, true)
            phase = .paused
        }
        append(batch.rows)
        if done != 0 && lookahead == nil {
            discardHandle()
            phase = .finished
        }
    }

    private func append(_ batch: [SearchRow]) {
        guard !batch.isEmpty else { return }
        let exact = batch.filter { $0.rank == 0 }
        rows.insert(contentsOf: exact, at: exactCount)
        exactCount += exact.count
        rows.append(contentsOf: batch.filter { $0.rank != 0 })
    }
}
