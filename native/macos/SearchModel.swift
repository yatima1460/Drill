import AppKit
import Combine
import CoreFoundation

enum SearchMode: String, CaseIterable {
    case files = "Files"
    case apps = "Apps"
}

struct SearchRow: Identifiable {
    var id: Data { path }
    let url: URL
    let path: Data
    let name: String
    let rank: UInt8
    let isDirectory: Bool
    let size: UInt64?
    let modifiedSeconds: Int64?
    let modifiedNanos: UInt32

    var displayPath: String { String(decoding: path, as: UTF8.self) }
    var parentBytes: Data.SubSequence {
        guard let slash = path.lastIndex(of: 0x2f) else { return path.prefix(0) }
        return path.prefix(upTo: slash == path.startIndex ? path.index(after: slash) : slash)
    }
    var parentPath: String { String(decoding: parentBytes, as: UTF8.self) }

    var sizeText: String {
        guard let size else { return "?" }
        if size == 0 { return isDirectory ? "" : "Empty" }
        if size < 1024 { return "1 KB" }
        var value = Double(size) / 1024
        for unit in ["KB", "MB", "GB", "TB", "PB"] {
            if value < 1024 { return String(format: "%.0f %@", value, unit) }
            value /= 1024
        }
        return String(format: "%.1f EB", value)
    }

    var dateText: String {
        guard let modifiedSeconds, (-8_334_601_228_800...8_210_266_876_799).contains(modifiedSeconds)
        else { return "?" }
        var seconds = time_t(modifiedSeconds)
        var fields = tm()
        guard localtime_r(&seconds, &fields) != nil else { return "?" }
        let year = fields.tm_year + 1900
        let prefix = String(format: (0...9999).contains(year) ? "%04d" : "%+05d", year)
        return prefix + String(format: "/%02d/%02d %02d:%02d:%02d", fields.tm_mon + 1,
                               fields.tm_mday, fields.tm_hour, fields.tm_min, fields.tm_sec)
    }
}

enum ResultColumn: String, CaseIterable {
    case name = "Name", path = "Path", size = "Size", date = "Date"

    func text(for row: SearchRow) -> String {
        switch self {
        case .name: return row.name
        case .path: return row.parentPath
        case .size: return row.sizeText
        case .date: return row.dateText
        }
    }
}

struct ResultSort: Equatable {
    let column: ResultColumn
    let ascending: Bool

    func precedes(_ left: SearchRow, _ right: SearchRow) -> Bool {
        let (a, b) = ascending ? (left, right) : (right, left)
        switch column {
        case .name:
            let x = a.name.lowercased().utf8, y = b.name.lowercased().utf8
            if !x.elementsEqual(y) { return x.lexicographicallyPrecedes(y) }
        case .path:
            break
        case .size:
            if a.size != b.size {
                guard let x = a.size else { return true }
                guard let y = b.size else { return false }
                return x < y
            }
        case .date:
            if a.modifiedSeconds != b.modifiedSeconds {
                return (a.modifiedSeconds ?? .min) < (b.modifiedSeconds ?? .min)
            }
            if a.modifiedNanos != b.modifiedNanos { return a.modifiedNanos < b.modifiedNanos }
        }
        return a.path.withUnsafeBytes { left in
            b.path.withUnsafeBytes { right in
                drill_compare_paths(left.bindMemory(to: UInt8.self).baseAddress, left.count,
                                    right.bindMemory(to: UInt8.self).baseAddress, right.count,
                                    column == .path) < 0
            }
        }
    }
}

// The Rust callback borrows its arguments only until it returns.
private final class HitBatch {
    var rows: [SearchRow] = []

    static let receive: DrillHitCallback = { context, bytes, count, name, rank, isDir, size, modified, nanos in
        guard let context, let bytes, let name,
              let url = CFURLCreateFromFileSystemRepresentation(nil, bytes, count, isDir) else {
            return
        }
        let batch = Unmanaged<HitBatch>.fromOpaque(context).takeUnretainedValue()
        // CFURL retains the original bytes, including non-UTF-8 names, through Launch Services.
        batch.rows.append(SearchRow(url: url as URL, path: Data(bytes: bytes, count: count),
                                    name: String(cString: name), rank: rank, isDirectory: isDir,
                                    size: size == .max ? nil : size,
                                    modifiedSeconds: modified == .min ? nil : modified, modifiedNanos: nanos))
    }
}

@MainActor
final class SearchModel: ObservableObject {
    enum Phase { case empty, searching, paused, stopped, finished, invalid }

    @Published var query = "" {
        didSet {
            // Rust regexes distinguish composed and decomposed Unicode.
            if !oldValue.utf8.elementsEqual(query.utf8) { replaceSearch() }
        }
    }
    @Published var mode = SearchMode.files { didSet { if oldValue != mode { replaceSearch() } } }
    @Published var selection: Data?
    @Published private(set) var rows: [SearchRow] = [] { didSet { rowsRevision &+= 1 } }
    private(set) var rowsRevision: UInt = 0
    private(set) var sort: ResultSort?
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
    private var additionalRoots: [Data] = []
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

    func open(row: SearchRow) { openURL(row.url) }

    func openSelection() {
        if let selection, let row = rows.first(where: { $0.path == selection }) { open(row: row) }
    }

    func moveSelection(by offset: Int) {
        guard !rows.isEmpty else { return }
        let current = selection.flatMap { path in rows.firstIndex { $0.path == path } } ?? -1
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

    // Rust limits each poll to one small batch. Give the main actor a turn for
    // input and painting while results are queued, and back off when it is idle.
    var waitAfterPoll: @MainActor (_ filledBatch: Bool) async throws -> Void = { filledBatch in
        if filledBatch {
            await Task.yield()
        } else {
            try await Task.sleep(nanoseconds: 30_000_000)
        }
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
                let filledBatch = self?.poll() ?? false
                guard self?.isSearching == true, let wait = self?.waitAfterPoll else { return }
                do { try await wait(filledBatch) } catch { return }
            }
        }
    }

    func addSearchRoot(_ url: URL) {
        guard url.isFileURL, let path = url.withUnsafeFileSystemRepresentation({ pointer in
            pointer.map { Data(bytes: $0, count: strlen($0) + 1) }
        }) else { return }
        if !additionalRoots.contains(path) { additionalRoots.append(path) }
        // Selecting a previously added folder can grant access it lacked on
        // the last scan. Keep the user's explicit Stop until their next query.
        if phase != .stopped && (mode == .apps || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            replaceSearch()
        }
    }

    private func start() {
        let apps = mode == .apps
        let additional = additionalRoots.reduce(into: Data()) { $0.append($1) }
        handle = additional.withUnsafeBytes { buffer in
            let paths = buffer.bindMemory(to: UInt8.self)
            return query.withCString { text in
                func begin(_ base: UnsafePointer<UInt8>?, _ count: Int) -> OpaquePointer? {
                    drill_search_start_with_roots(text, apps, base, count,
                                                  paths.baseAddress, paths.count)
                }
                guard let root else { return begin(nil, 0) }
                return root.withUnsafeFileSystemRepresentation { path in
                    guard let path else { return nil }
                    let base = UnsafeRawPointer(path).assumingMemoryBound(to: UInt8.self)
                    return begin(base, strlen(path))
                }
            }
        }
        if handle == nil {
            validationMessage = "Could not start the search."
            phase = .invalid
        }
    }

    private func poll() -> Bool {
        guard let handle else { return false }
        let batch = HitBatch()
        let maxHits = min(Int(pollBatchSize), limit - rows.count + 1)
        let done = drill_search_poll(handle, UInt32(maxHits),
                                     Unmanaged.passUnretained(batch).toOpaque(), HitBatch.receive)
        if let error = drill_search_error(handle) {
            validationMessage = String(cString: error)
            discardHandle()
            phase = .invalid
            return false
        }
        let filledBatch = batch.rows.count == maxHits
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
        return filledBatch
    }

    func setSort(_ order: ResultSort) {
        guard sort != order else { return }
        sort = order
        rows.sort(by: order.precedes)
    }

    func append(_ batch: [SearchRow]) {
        guard !batch.isEmpty else { return }
        if let sort {
            // Merge the little incoming run into the already sorted visible results.
            let incoming = batch.sorted(by: sort.precedes)
            var merged: [SearchRow] = []
            merged.reserveCapacity(rows.count + incoming.count)
            var start = 0
            for row in incoming {
                var low = start
                var high = rows.count
                while low < high {
                    let middle = low + (high - low) / 2
                    if sort.precedes(rows[middle], row) { low = middle + 1 }
                    else { high = middle }
                }
                merged.append(contentsOf: rows[start..<low])
                merged.append(row)
                start = low
            }
            merged.append(contentsOf: rows[start...])
            rows = merged
        } else {
            let exact = batch.filter { $0.rank == 0 }
            if !exact.isEmpty {
                rows.insert(contentsOf: exact, at: exactCount)
                exactCount += exact.count
            }
            rows.append(contentsOf: batch.filter { $0.rank != 0 })
        }
    }
}
