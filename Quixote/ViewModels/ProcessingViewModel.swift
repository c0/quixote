import Foundation
import AppKit

private let kKeychainOpenAIKey = "openai-api-key"

@MainActor
final class ProcessingViewModel: ObservableObject {
    struct PersistedCompletedResultsStore: Codable {
        var resultsByFileID: [UUID: [String: PromptResult]]
    }

    enum RunState: Equatable {
        case idle
        case running(completed: Int, total: Int)
        case paused(completed: Int, total: Int)
        case completed(Int)   // total processed
        case failed(String)
    }

    private struct RunContext {
        let prompts: [Prompt]
        let rows: [Row]
        let columns: [ColumnDef]
        let models: [ModelConfig]
        let apiKey: String
        let maxRetries: Int
    }

    /// Codable snapshot of queue state for disk persistence.
    struct QueueSnapshot: Codable {
        let prompts: [Prompt]
        let rows: [Row]
        let columns: [ColumnDef]
        let models: [ModelConfig]
        let maxRetries: Int
        let results: [String: PromptResult]
        let completedCount: Int
        let totalCount: Int
    }

    @Published var runState: RunState = .idle
    // Results keyed by composite "\(promptID)-\(rowID)-\(modelID)"
    @Published var results: [String: PromptResult] = [:]

    private var runTask: Task<Void, Never>?
    private var pauseContinuation: CheckedContinuation<Void, Never>?
    private var runContext: RunContext?
    private var maxConcurrency = 2
    private var rateLimiter = RateLimiter(requestsPerSecond: 5)
    private var saveTask: Task<Void, Never>?
    private var completedResultsSaveTask: Task<Void, Never>?
    private var activeFileID: UUID?
    private var persistedCompletedResultsByFileID: [UUID: [String: PromptResult]] = [:]

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
                self.saveCompletedResultsNow()
            }
        }

        loadCompletedResultsStore()
    }

    // MARK: - Composite key

    private func resultKey(promptID: UUID, rowID: UUID, modelID: String) -> String {
        "\(promptID.uuidString)-\(rowID.uuidString)-\(modelID)"
    }

    private func resultKeys(
        prompts: [Prompt],
        rows: [Row],
        models: [ModelConfig]
    ) -> Set<String> {
        Set(
            prompts.flatMap { prompt in
                rows.flatMap { row in
                    models.map { model in
                        resultKey(promptID: prompt.id, rowID: row.id, modelID: model.id)
                    }
                }
            }
        )
    }

    // MARK: - Start

    func startRun(
        prompts: [Prompt],
        rows: [Row],
        columns: [ColumnDef],
        models: [ModelConfig],
        apiKey: String,
        concurrency: Int = 2,
        rateLimit: Double = 5,
        maxRetries: Int = 3
    ) {
        guard !isActive, !models.isEmpty, !prompts.isEmpty else { return }
        maxConcurrency = max(1, concurrency)
        rateLimiter = RateLimiter(requestsPerSecond: max(1, rateLimit))
        runContext = RunContext(
            prompts: prompts, rows: rows, columns: columns,
            models: models, apiKey: apiKey, maxRetries: maxRetries
        )
        activeFileID = prompts.first?.fileID
        isRestoredFromDisk = false
        let keysToReplace = resultKeys(prompts: prompts, rows: rows, models: models)
        results = results.filter { !keysToReplace.contains($0.key) }
        if let activeFileID,
           var persisted = persistedCompletedResultsByFileID[activeFileID] {
            persisted = persisted.filter { !keysToReplace.contains($0.key) }
            if persisted.isEmpty {
                persistedCompletedResultsByFileID.removeValue(forKey: activeFileID)
            } else {
                persistedCompletedResultsByFileID[activeFileID] = persisted
            }
            scheduleCompletedResultsSave()
        }
        clearSavedState()
        let total = prompts.count * rows.count * models.count
        runState = .running(completed: 0, total: total)

        let service = OpenAIService(apiKey: apiKey)

        runTask = Task {
            await processRows(prompts: prompts, rows: rows,
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
        persistCompletedResultsForActiveFile()
    }

    func clearResults() {
        results = [:]
        runContext = nil
        isRestoredFromDisk = false
        runState = .idle
        clearSavedState()
        persistCompletedResultsForActiveFile()
    }

    func clearDisplayedResults() {
        results = [:]
        runContext = nil
        isRestoredFromDisk = false
        runState = .idle
        clearSavedState()
    }

    func setActiveFile(_ fileID: UUID?) {
        activeFileID = fileID
    }

    func loadPersistedCompletedResults(for fileID: UUID) {
        activeFileID = fileID
        guard !isActive else { return }
        runContext = nil
        isRestoredFromDisk = false
        results = persistedCompletedResultsByFileID[fileID] ?? [:]
        if results.isEmpty {
            runState = .idle
        } else if case .failed = runState {
            runState = .idle
        }
    }

    func clearPersistedCompletedResults(for fileID: UUID) {
        persistedCompletedResultsByFileID.removeValue(forKey: fileID)
        scheduleCompletedResultsSave()
        if activeFileID == fileID, !isActive {
            results = [:]
            runState = .idle
        }
    }

    func retryFailed(concurrency: Int, rateLimit: Double) {
        guard let ctx = runContext, !isActive else { return }

        maxConcurrency = max(1, concurrency)
        rateLimiter = RateLimiter(requestsPerSecond: max(1, rateLimit))

        let service = OpenAIService(apiKey: ctx.apiKey)
        let columns = ctx.columns
        let maxRetries = ctx.maxRetries

        let promptsByID = Dictionary(uniqueKeysWithValues: ctx.prompts.map { ($0.id, $0) })
        let promptScopedWorkItems = results.values
            .filter { $0.status == .failed }
            .compactMap { result -> (Prompt, Row, ModelConfig)? in
                guard let prompt = promptsByID[result.promptID],
                      let row = ctx.rows.first(where: { $0.id == result.rowID }),
                      let model = ctx.models.first(where: { $0.id == result.modelID }) else { return nil }
                return (prompt, row, model)
            }

        guard !promptScopedWorkItems.isEmpty else { return }

        runState = .running(completed: 0, total: promptScopedWorkItems.count)

        runTask = Task {
            await processWorkItems(promptScopedWorkItems, columns: columns,
                                   service: service, maxRetries: maxRetries)
            if Task.isCancelled { return }
            if case .running(_, let total) = runState {
                runState = .completed(total)
                clearSavedState()
            }
        }
    }

    func retryResult(rowID: UUID, promptID: UUID, modelID: String) {
        guard let ctx = runContext,
              let prompt = ctx.prompts.first(where: { $0.id == promptID }),
              let row = ctx.rows.first(where: { $0.id == rowID }),
              let model = ctx.models.first(where: { $0.id == modelID }) else { return }

        let key = resultKey(promptID: promptID, rowID: rowID, modelID: modelID)
        if var current = results[key] {
            current.status = .inProgress
            results[key] = current
        }

        let expandedPrompt = InterpolationEngine.expand(
            template: prompt.template, row: row, columns: ctx.columns)
        let service = OpenAIService(apiKey: ctx.apiKey)
        let maxRetries = ctx.maxRetries

        Task {
            let result = await Self.callService(
                service: service, prompt: expandedPrompt,
                systemMessage: prompt.systemMessage,
                params: prompt.parameters,
                row: row, promptID: prompt.id, model: model,
                maxRetries: maxRetries
            )
            if result.status == .completed,
               let text = result.responseText,
               let usage = result.tokenUsage {
                let key = ResponseCache.cacheKey(
                    expandedPrompt: expandedPrompt,
                    systemMessage: prompt.systemMessage,
                    modelID: result.modelID,
                    params: prompt.parameters)
                ResponseCache.shared.store(
                    entry: CachedEntry(
                        responseText: text,
                        tokenUsage: usage,
                        durationMs: result.durationMs ?? 0,
                        costUSD: result.costUSD ?? 0,
                        cosineSimilarity: result.cosineSimilarity ?? 0,
                        cachedAt: Date()
                    ),
                    for: key)
            }
            results[resultKey(promptID: result.promptID, rowID: result.rowID, modelID: result.modelID)] = result
            persistCompletedResultsForActiveFile()
        }
    }

    // MARK: - Disk resume

    private func resumeRemaining(ctx: RunContext, completedSoFar: Int, total: Int) {
        let completedKeys = Set(results.filter { $0.value.status == .completed }.keys)
        let remainingItems: [(Prompt, Row, ModelConfig)] = ctx.prompts.flatMap { prompt in
            ctx.rows.flatMap { row in
                ctx.models.compactMap { model in
                    let key = resultKey(promptID: prompt.id, rowID: row.id, modelID: model.id)
                    return completedKeys.contains(key) ? nil : (prompt, row, model)
                }
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
            prompts: ctx.prompts, rows: ctx.rows, columns: ctx.columns,
            models: ctx.models, apiKey: apiKey, maxRetries: ctx.maxRetries
        )
        activeFileID = ctx.prompts.first?.fileID

        runState = .running(completed: completedSoFar, total: total)
        let service = OpenAIService(apiKey: apiKey)
        let columns = ctx.columns
        let maxRetries = ctx.maxRetries

        runTask = Task {
            await processWorkItems(remainingItems, columns: columns,
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

    private static let completedResultsURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Quixote")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("completed-results.json")
    }()

    func restoreIfNeeded() {
        guard runState == .idle, runContext == nil else { return }
        guard let data = try? Data(contentsOf: Self.persistenceURL),
              let snapshot = try? JSONDecoder().decode(QueueSnapshot.self, from: data) else { return }

        let apiKey = KeychainHelper.read(for: kKeychainOpenAIKey) ?? ""
        runContext = RunContext(
            prompts: snapshot.prompts, rows: snapshot.rows, columns: snapshot.columns,
            models: snapshot.models, apiKey: apiKey, maxRetries: snapshot.maxRetries
        )
        activeFileID = snapshot.prompts.first?.fileID
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
            prompts: ctx.prompts, rows: ctx.rows, columns: ctx.columns,
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

    private func loadCompletedResultsStore() {
        guard let data = try? Data(contentsOf: Self.completedResultsURL),
              let store = try? JSONDecoder().decode(PersistedCompletedResultsStore.self, from: data) else { return }
        persistedCompletedResultsByFileID = store.resultsByFileID
    }

    private func scheduleCompletedResultsSave() {
        completedResultsSaveTask?.cancel()
        completedResultsSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            saveCompletedResultsNow()
        }
    }

    private func saveCompletedResultsNow() {
        let store = PersistedCompletedResultsStore(resultsByFileID: persistedCompletedResultsByFileID)
        let data = try? JSONEncoder().encode(store)
        try? data?.write(to: Self.completedResultsURL, options: .atomic)
    }

    private func persistCompletedResultsForActiveFile() {
        guard let activeFileID else { return }
        let completed = results.filter { $0.value.status == .completed }
        if completed.isEmpty {
            persistedCompletedResultsByFileID.removeValue(forKey: activeFileID)
        } else {
            persistedCompletedResultsByFileID[activeFileID] = completed
        }
        scheduleCompletedResultsSave()
    }

    // MARK: - Processing

    private func processRows(
        prompts: [Prompt],
        rows: [Row],
        columns: [ColumnDef],
        models: [ModelConfig],
        service: OpenAIService,
        maxRetries: Int
    ) async {
        let workItems = prompts.flatMap { prompt in
            rows.flatMap { row in
                models.map { model in (prompt, row, model) }
            }
        }
        await processWorkItems(workItems, columns: columns, service: service, maxRetries: maxRetries)

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
        _ workItems: [(Prompt, Row, ModelConfig)],
        columns: [ColumnDef],
        service: OpenAIService,
        maxRetries: Int
    ) async {
        let cache = ResponseCache.shared

        // --- Partition: apply cache hits immediately, collect misses ---
        var misses: [(Prompt, Row, ModelConfig)] = []
        // Map composite key → expandedPrompt for storing results after API calls
        var expandedPrompts: [String: String] = [:]

        for (prompt, row, model) in workItems {
            let expanded = InterpolationEngine.expand(
                template: prompt.template, row: row, columns: columns)
            let key = ResponseCache.cacheKey(
                expandedPrompt: expanded,
                systemMessage: prompt.systemMessage,
                modelID: model.id,
                params: prompt.parameters)

            if let entry = cache.entry(for: key) {
                var result = PromptResult(
                    runID: UUID(), rowID: row.id, promptID: prompt.id, modelID: model.id)
                result.responseText = entry.responseText
                result.tokenUsage = entry.tokenUsage
                result.durationMs = entry.durationMs
                result.costUSD = entry.costUSD
                result.cosineSimilarity = entry.cosineSimilarity
                result.status = .completed
                updateResult(result)
            } else {
                let compositeKey = resultKey(promptID: prompt.id, rowID: row.id, modelID: model.id)
                expandedPrompts[compositeKey] = expanded
                misses.append((prompt, row, model))
            }
        }

        guard !misses.isEmpty else { return }

        // --- Dispatch API calls for cache misses ---
        await withTaskGroup(of: PromptResult.self) { group in
            var iterator = misses.makeIterator()
            var active = 0

            while active < maxConcurrency, let (prompt, row, model) = iterator.next() {
                let compositeKey = resultKey(promptID: prompt.id, rowID: row.id, modelID: model.id)
                let expanded = expandedPrompts[compositeKey]!
                group.addTask { [model, prompt, rateLimiter] in
                    try? await rateLimiter.waitForSlot()
                    return await Self.callService(
                        service: service, prompt: expanded,
                        systemMessage: prompt.systemMessage,
                        params: prompt.parameters,
                        row: row, promptID: prompt.id, model: model,
                        maxRetries: maxRetries)
                }
                active += 1
            }

            for await result in group {
                // Store completed results in cache
                if result.status == .completed,
                   let text = result.responseText,
                   let usage = result.tokenUsage {
                    let compositeKey = resultKey(promptID: result.promptID, rowID: result.rowID, modelID: result.modelID)
                    if let expanded = expandedPrompts[compositeKey] {
                        guard let prompt = workItems.first(where: {
                            $0.0.id == result.promptID && $0.1.id == result.rowID && $0.2.id == result.modelID
                        })?.0 else {
                            updateResult(result)
                            continue
                        }
                        let key = ResponseCache.cacheKey(
                            expandedPrompt: expanded,
                            systemMessage: prompt.systemMessage,
                            modelID: result.modelID,
                            params: prompt.parameters)
                        cache.store(
                            entry: CachedEntry(
                                responseText: text,
                                tokenUsage: usage,
                                durationMs: result.durationMs ?? 0,
                                costUSD: result.costUSD ?? 0,
                                cosineSimilarity: result.cosineSimilarity ?? 0,
                                cachedAt: Date()),
                            for: key)
                    }
                }

                updateResult(result)

                if let (prompt, row, model) = iterator.next() {
                    await waitIfPaused()
                    guard !Task.isCancelled else { break }
                    let compositeKey = resultKey(promptID: prompt.id, rowID: row.id, modelID: model.id)
                    let expanded = expandedPrompts[compositeKey]!
                    group.addTask { [model, prompt, rateLimiter] in
                        try? await rateLimiter.waitForSlot()
                        return await Self.callService(
                            service: service, prompt: expanded,
                            systemMessage: prompt.systemMessage,
                            params: prompt.parameters,
                            row: row, promptID: prompt.id, model: model,
                            maxRetries: maxRetries)
                    }
                }
            }
        }
    }

    /// Bag-of-words cosine similarity between two strings. Returns 0–1.
    private static func cosineSimilarity(_ a: String, _ b: String) -> Double {
        func tokenize(_ s: String) -> [String: Int] {
            var freq: [String: Int] = [:]
            let words = s.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { !$0.isEmpty }
            for w in words { freq[w, default: 0] += 1 }
            return freq
        }
        let va = tokenize(a)
        let vb = tokenize(b)
        guard !va.isEmpty, !vb.isEmpty else { return 0 }
        let dot = va.reduce(0.0) { acc, pair in
            acc + Double(pair.value) * Double(vb[pair.key] ?? 0)
        }
        let magA = sqrt(va.values.reduce(0.0) { $0 + Double($1 * $1) })
        let magB = sqrt(vb.values.reduce(0.0) { $0 + Double($1 * $1) })
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }

    private static func callService(
        service: OpenAIService,
        prompt: String,
        systemMessage: String,
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
                    prompt: prompt,
                    systemMessage: systemMessage,
                    model: model,
                    params: params)
                result.responseText = response.text
                result.tokenUsage = response.tokenUsage
                result.durationMs = response.durationMs
                result.costUSD = model.costFor(
                    inputTokens: response.tokenUsage.input,
                    outputTokens: response.tokenUsage.output
                )
                result.cosineSimilarity = cosineSimilarity(prompt, response.text)
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
        results[resultKey(promptID: result.promptID, rowID: result.rowID, modelID: result.modelID)] = result
        persistCompletedResultsForActiveFile()
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
