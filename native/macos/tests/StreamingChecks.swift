import Foundation

/// A one-result batch makes every delivered row a deterministic backlog signal.
@MainActor
func checkStreamingBacklog() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent("drill-stream-\(UUID())", isDirectory: true)
    try manager.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }
    let names = Set((0..<512).map { "needle-\($0).txt" })
    for name in names {
        try Data().write(to: root.appendingPathComponent(name))
    }

    let model = SearchModel(root: root, pollBatchSize: 1)
    let wait = model.waitAfterPoll
    var fullPolls = 0
    var rowsWhenMainQueueRan = 0
    model.waitAfterPoll = { [weak model] filledBatch in
        if filledBatch {
            fullPolls += 1
            if fullPolls == 1 {
                DispatchQueue.main.async {
                    rowsWhenMainQueueRan = model?.rows.count ?? 0
                }
            }
        }
        try await wait(filledBatch)
    }
    defer { model.stop() }
    model.query = "needle"
    // An unconditional 30 ms wait takes over 15 seconds for 512 one-row polls.
    let deadline = ProcessInfo.processInfo.systemUptime + 8
    while model.isSearching && ProcessInfo.processInfo.systemUptime < deadline {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
    }
    guard model.phase == .finished, model.rows.count == names.count,
          Set(model.rows.map(\.name)) == names, fullPolls >= names.count - 1,
          (1..<names.count).contains(rowsWhenMainQueueRan) else {
        throw NSError(domain: "DrillStreamingChecks", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Backlog delivery failed: \(model.rows.count) rows, \(fullPolls) full polls, main queue ran at row \(rowsWhenMainQueueRan)."
        ])
    }
}
