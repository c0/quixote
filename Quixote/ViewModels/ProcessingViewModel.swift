import Foundation
import AppKit

private let kKeychainOpenAIKey = "openai-api-key"

@MainActor
final class ProcessingViewModel: ObservableObject {

    enum RunState: Equatable {
        case idle
        case running(completed: Int, total: Int)
        case paused(completed: Int, total: Int)
        case completed(Int)   // total processed
        case failed(String)
    }

    private struct RunContext {
        let prompt: Prompt
        let rows: [Row]
        let columns: [ColumnDef]
        let models: [ModelConfig]
        let apiKey: String
        let maxRetries: Int
    }

    /// Codable snapshot of queue state for disk persistence.
    struct QueueSnapshot: Codable {
        let prompt: Prompt
        let rows: [Row]
        let columns: [ColumnDef]
        let models: [ModelConfig]
        let maxRetries: Int
        let results: [String: PromptResult]
        let completedCount: Int
        let totalCount: Int
    }

    @Published var runState: RunState = .idle
    // Results keyed by composite "\(rowID)-\(modelID)" — supports multi-model
    @Published var results: [String: PromptResult] = [:]

    private var runTask: Task<Void, Never>?
    private var pauseContinuation: CheckedContinuation<Void, Never>?
    private var runContext: RunContext?
    private var maxConcurrency = 2
    private var rateLimiter = RateLimiter(requestsPerSecond: 5)
    private var saveTask: Task<Void, Never>?

    var isRunning: Bool {
        if case .running = runState { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = runState { return true }
        return false
    }

    var isActive: Bool {
        switch runState {
        case .running, .paused: return true
        default: return false
        }
    }

    var hasFailedResults: Bool {
        results.values.contains { $0.status == .failed }
    }

    /// True when state was restored from disk and hasn't been resumed yet.
    private(set) var isRestoredFromDisk = false

    var progress: Double {
        if case .running(let done, let total) = runState, total > 0 {
            return Double(done) / Double(total)
        }
        return 0
    }

    // MARK: - Init

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.saveQueueStateNow()
            }
        }
    }

    // MARK: - Composite key

    private func resultKey(rowID: UUID, modelID: String) -> String {
        "\(rowID.uuidString)-\(modelID)"
    }

    // MARK: - Start

    func startRun(
        prompt: Prompt,
        rows: [Row],
        columns: [ColumnDef],
        models: [ModelConfig],
        apiKey: String,
        concurrency: Int = 2,
        rateLimit: Double = 5,
        maxRetries: Int = 3
    ) {
        guard !isActive, !models.isEmpty else { return }
        maxConcurrency = max(1, concurrency)
        rateLimiter = RateLimiter(requestsPerSecond: max(1, rateLimit))
        runContext = RunContext(
            prompt: prompt, rows: rows, columns: columns,
            models: models, apiKey: apiKey, maxRetries: maxRetries
        )
        isRestoredFromDisk = false
        results = [:]
        clearSavedState()
        let total = rows.count * models.count
        runState = .running(completed: 0, total: total)

        let service = OpenAIService(apiKey: apiKey)

        runTask = Task {
            await processRows(prompt: prompt, rows: rows,
                              columns: columns, models: models,
                              service: service, maxRetries: maxRetries)
        }
    }

    func pause() {
        guard case .running(let done, let total) = runState else { return }
        runState = .paused(completed: done, total: total)
        saveQueueStateNow()
    }

    func resume() {
        guard case .paused(let done, let total) = runState else { return }

        if let continuation = pauseContinuation {
            // In-memory pause: resume the suspended task group
            runState = .running(completed: done, total: total)
            continuation.resume()
            pauseContinuation = nil
        } else if let ctx = runContext {
            // Disk restore: start a new task for remaining work items
            isRestoredFromDisk = false
            resumeRemaining(ctx: ctx, completedSoFar: done, total: total)
        }
    }

    func cancel() {
        pauseContinuation?.resume()
        pauseContinuation = nil
        runTask?.cancel()
        runTask = nil
        isRestoredFromDisk = false
        for (key, var result) in results {
            if result.status == .pending || result.status == .inProgress {
                result.status = .cancelled
                results[key] = result
            }
        }
        runState = .idle
        clearSavedState()
    }

    func retryFailed(concurrency: Int, rateLimit: Double) {
        guard let ctx = runContext, !isActive else { return }

        let failedWorkItems: [(Row, ModelConfig)] = results.values
            .filter { $0.status == .failed }
            .compactMap { result in
                guard let row = ctx.rows.first(where: { $0.id == result.rowID }),
                      let model = ctx.models.first(where: { $0.id == result.modelID })
                else { return nil }
                return (row, model)
            }

        guard !failedWorkItems.isEmpty else { return }

        maxConcurrency = max(1, concurrency)
        rateLimiter = RateLimiter(requestsPerSecond: max(1, rateLimit))
        runState = .running(completed: 0, total: failedWorkItems.count)

        let service = OpenAIService(apiKey: ctx.apiKey)
        let prompt = ctx.prompt
        let columns = ctx.columns
        let maxRetries = ctx.maxRetries

        runTask = Task {
            await processWorkItems(failedWorkItems, prompt: prompt, columns: columns,
                                   service: service, maxRetries: maxRetries)
            if Task.isCancelled { return }
            if case .running(_, let total) = runState {
                runState = .completed(total)
                clearSavedState()
            }
        }
    }

    func retryResult(rowID: UUID, modelID: String) {
        guard let ctx = runContext,
              let row = ctx.rows.first(where: { $0.id == rowID }),
              let model = ctx.models.first(where: { $0.id == modelID }) else { return }

        let key = resultKey(rowID: rowID, modelID: modelID)
        if var current = results[key] {
            current.status = .inProgress
            results[key] = current
        }

        let expandedPrompt = InterpolationEngine.expand(
            template: ctx.prompt.template, row: row, columns: ctx.columns)
        let service = OpenAIService(apiKey: ctx.apiKey)
        let maxRetries = ctx.maxRetries

        Task {
            let result = await Self.callService(
                service: service, prompt: expandedPrompt,
                params: ctx.prompt.parameters,
                row: row, promptID: ctx.prompt.id, model: model,
                maxRetries: maxRetries
            )
            results[resultKey(rowID: result.rowID, modelID: result.modelID)] = result
        }
    }

    // MARK: - Disk resume

    private func resumeRemaining(ctx: RunContext, completedSoFar: Int, total: Int) {
        let completedKeys = Set(results.filter { $0.value.status == .completed }.keys)
        let remainingItems: [(Row, ModelConfig)] = ctx.rows.flatMap { row in
            ctx.models.compactMap { model in
                let key = resultKey(rowID: row.id, modelID: model.id)
                return completedKeys.contains(key) ? nil : (row, model)
            }
        }

        guard !remainingItems.isEmpty else {
            runState = .completed(total)
            clearSavedState()
            return
        }

        // Re-read settings from UserDefaults for concurrency/rate
        let concurrency = UserDefaults.standard.integer(forKey: "quixote.concurrency")
        let rateLimit = UserDefaults.standard.integer(forKey: "quixote.rateLimit")
        maxConcurrency = max(1, concurrency == 0 ? 2 : concurrency)
        rateLimiter = RateLimiter(requestsPerSecond: max(1, Double(rateLimit == 0 ? 5 : rateLimit)))

        let apiKey = KeychainHelper.read(for: kKeychainOpenAIKey) ?? ""
        guard !apiKey.isEmpty else {
            runState = .failed("No API key — set one in Settings to resume")
            return
        }

        // Update runContext with fresh apiKey
        runContext = RunContext(
            prompt: ctx.prompt, rows: ctx.rows, columns: ctx.columns,
            models: ctx.models, apiKey: apiKey, maxRetries: ctx.maxRetries
        )

        runState = .running(completed: completedSoFar, total: total)
        let service = OpenAIService(apiKey: apiKey)
        let prompt = ctx.prompt
        let columns = ctx.columns
        let maxRetries = ctx.maxRetries

        runTask = Task {
            await processWorkItems(remainingItems, prompt: prompt, columns: columns,
                                   service: service, maxRetries: maxRetries)
            if Task.isCancelled { return }
            switch runState {
            case .running(_, let t), .paused(_, let t):
                runState = .completed(t)
                clearSavedState()
            default:
                break
            }
        }
    }

    // MARK: - Queue persistence

    private static let persistenceURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Quixote")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("queue-state.json")
    }()

    func restoreIfNeeded() {
        guard runState == .idle, runContext == nil else { return }
        guard let data = try? Data(contentsOf: Self.persistenceURL),
              let snapshot = try? JSONDecoder().decode(QueueSnapshot.self, from: data) else { return }

        let apiKey = KeychainHelper.read(for: kKeychainOpenAIKey) ?? ""
        runContext = RunContext(
            prompt: snapshot.prompt, rows: snapshot.rows, columns: snapshot.columns,
            models: snapshot.models, apiKey: apiKey, maxRetries: snapshot.maxRetries
        )
        results = snapshot.results
        isRestoredFromDisk = true
        runState = .paused(completed: snapshot.completedCount, total: snapshot.totalCount)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            saveQueueStateNow()
        }
    }

    private func saveQueueStateNow() {
        guard let ctx = runContext else { return }
        let completedCount: Int
        let totalCount: Int
        switch runState {
        case .running(let c, let t), .paused(let c, let t):
            completedCount = c; totalCount = t
        default:
            return  // Only save while active
        }

        let snapshot = QueueSnapshot(
            prompt: ctx.prompt, rows: ctx.rows, columns: ctx.columns,
            models: ctx.models, maxRetries: ctx.maxRetries,
            results: results,
            completedCount: completedCount, totalCount: totalCount
        )

        let data = try? JSONEncoder().encode(snapshot)
        try? data?.write(to: Self.persistenceURL, options: .atomic)
    }

    private func clearSavedState() {
        saveTask?.cancel()
        saveTask = nil
        try? FileManager.default.removeItem(at: Self.persistenceURL)
    }

    // MARK: - Processing

    private func processRows(
        prompt: Prompt,
        rows: [Row],
        columns: [ColumnDef],
        models: [ModelConfig],
        service: OpenAIService,
        maxRetries: Int
    ) async {
        let workItems = rows.flatMap { row in models.map { model in (row, model) } }
        await processWorkItems(workItems, prompt: prompt, columns: columns, service: service, maxRetries: maxRetries)

        if Task.isCancelled { return }
        switch runState {
        case .running(_, let total), .paused(_, let total):
            runState = .completed(total)
            clearSavedState()
        default:
            break
        }
    }

    private func processWorkItems(
        _ workItems: [(Row, ModelConfig)],
        prompt: Prompt,
        columns: [ColumnDef],
        service: OpenAIService,
        maxRetries: Int
    ) async {
        await withTaskGroup(of: PromptResult.self) { group in
            var iterator = workItems.makeIterator()
            var active = 0

            // Seed up to maxConcurrency
            while active < maxConcurrency, let (row, model) = iterator.next() {
                let expandedPrompt = InterpolationEngine.expand(
                    template: prompt.template, row: row, columns: columns)
                group.addTask { [model, prompt, rateLimiter] in
                    try? await rateLimiter.waitForSlot()
                    return await Self.callService(
                        service: service, prompt: expandedPrompt,
                        params: prompt.parameters,
                        row: row, promptID: prompt.id, model: model,
                        maxRetries: maxRetries)
                }
                active += 1
            }

            // Drain and refill
            for await result in group {
                updateResult(result)
                if let (row, model) = iterator.next() {
                    await waitIfPaused()
                    guard !Task.isCancelled else { break }
                    let expandedPrompt = InterpolationEngine.expand(
                        template: prompt.template, row: row, columns: columns)
                    group.addTask { [model, prompt, rateLimiter] in
                        try? await rateLimiter.waitForSlot()
                        return await Self.callService(
                            service: service, prompt: expandedPrompt,
                            params: prompt.parameters,
                            row: row, promptID: prompt.id, model: model,
                            maxRetries: maxRetries)
                    }
                }
            }
        }
    }

    private static func callService(
        service: OpenAIService,
        prompt: String,
        params: LLMParameters,
        row: Row,
        promptID: UUID,
        model: ModelConfig,
        maxRetries: Int
    ) async -> PromptResult {
        let runID = UUID()
        var result = PromptResult(
            runID: runID,
            rowID: row.id,
            promptID: promptID, modelID: model.id)
        result.status = .inProgress

        var attempt = 0
        while true {
            do {
                let response = try await service.complete(
                    prompt: prompt, model: model, params: params)
                result.responseText = response.text
                result.tokenUsage = response.tokenUsage
                result.durationMs = response.durationMs
                result.costUSD = model.costFor(
                    inputTokens: response.tokenUsage.input,
                    outputTokens: response.tokenUsage.output
                )
                result.status = .completed
                return result
            } catch is CancellationError {
                result.status = .cancelled
                return result
            } catch {
                if attempt < maxRetries, !Task.isCancelled {
                    attempt += 1
                    result.retryCount = attempt
                    continue
                }
                result.responseText = error.localizedDescription
                result.status = .failed
                return result
            }
        }
    }

    private func updateResult(_ result: PromptResult) {
        results[resultKey(rowID: result.rowID, modelID: result.modelID)] = result
        switch runState {
        case .running(let done, let total):
            runState = .running(completed: done + 1, total: total)
        case .paused(let done, let total):
            runState = .paused(completed: done + 1, total: total)
        default:
            break
        }
        scheduleSave()
    }

    private func waitIfPaused() async {
        guard isPaused else { return }
        await withCheckedContinuation { continuation in
            pauseContinuation = continuation
        }
    }
}
