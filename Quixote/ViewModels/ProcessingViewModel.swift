import AppKit
import Foundation

@MainActor
final class ProcessingViewModel: ObservableObject {
    private struct AnalyticsScores {
        let cosineSimilarity: Double
        let rouge1: Double
        let rouge2: Double
        let rougeL: Double
    }

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
        let modelConfigs: [ResolvedFileModelConfig]
        let providerSecrets: [String: String]
        let maxRetries: Int
    }

    /// Codable snapshot of queue state for disk persistence.
    struct QueueSnapshot: Codable {
        let prompts: [Prompt]
        let rows: [Row]
        let columns: [ColumnDef]
        let modelConfigs: [ResolvedFileModelConfig]
        let maxRetries: Int
        let results: [String: PromptResult]
        let completedCount: Int
        let totalCount: Int
    }

    @Published var runState: RunState = .idle
    // Results keyed by composite "\(promptID)-\(rowID)-\(modelConfigID)"
    @Published var results: [String: PromptResult] = [:]
    @Published private(set) var runStartedAt: Date?

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

    private func resultKey(promptID: UUID, rowID: UUID, modelConfigID: UUID) -> String {
        "\(promptID.uuidString)-\(rowID.uuidString)-\(modelConfigID.uuidString)"
    }

    private func resultKeys(
        prompts: [Prompt],
        rows: [Row],
        modelConfigs: [ResolvedFileModelConfig]
    ) -> Set<String> {
        Set(
            prompts.flatMap { prompt in
                rows.flatMap { row in
                    modelConfigs.map { config in
                        resultKey(promptID: prompt.id, rowID: row.id, modelConfigID: config.id)
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
        modelConfigs: [ResolvedFileModelConfig],
        providerSecrets: [String: String],
        concurrency: Int = 2,
        rateLimit: Double = 5,
        maxRetries: Int = 3
    ) {
        guard !isActive, !modelConfigs.isEmpty, !prompts.isEmpty else { return }
        maxConcurrency = max(1, concurrency)
        rateLimiter = RateLimiter(requestsPerSecond: max(1, rateLimit))
        runContext = RunContext(
            prompts: prompts, rows: rows, columns: columns,
            modelConfigs: modelConfigs, providerSecrets: providerSecrets, maxRetries: maxRetries
        )
        activeFileID = prompts.first?.fileID
        isRestoredFromDisk = false
        let keysToReplace = resultKeys(prompts: prompts, rows: rows, modelConfigs: modelConfigs)
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
        let total = prompts.count * rows.count * modelConfigs.count
        runStartedAt = Date()
        runState = .running(completed: 0, total: total)

        runTask = Task {
            await processRows(prompts: prompts, rows: rows,
                              columns: columns, modelConfigs: modelConfigs,
                              providerSecrets: providerSecrets, maxRetries: maxRetries)
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
                result.finishedAt = Date()
                results[key] = result
            }
        }
        runStartedAt = nil
        runState = .idle
        clearSavedState()
        persistCompletedResultsForActiveFile()
    }

    func clearResults() {
        results = [:]
        runContext = nil
        isRestoredFromDisk = false
        runStartedAt = nil
        runState = .idle
        clearSavedState()
        persistCompletedResultsForActiveFile()
    }

    func clearDisplayedResults() {
        results = [:]
        runContext = nil
        isRestoredFromDisk = false
        runStartedAt = nil
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
        runStartedAt = nil
        results = persistedCompletedResultsByFileID[fileID] ?? [:]
        if results.isEmpty {
            runState = .idle
        } else if case .failed = runState {
            runState = .idle
        }
    }

    func hydrateCachedCompletedResults(
        prompts: [Prompt],
        rows: [Row],
        columns: [ColumnDef],
        modelConfigs: [ResolvedFileModelConfig]
    ) {
        guard !isActive, !prompts.isEmpty, !rows.isEmpty, !modelConfigs.isEmpty else { return }
        activeFileID = prompts.first?.fileID

        let cache = ResponseCache.shared
        var hydratedResults = results

        for prompt in prompts {
            for row in rows {
                let expanded = InterpolationEngine.expand(
                    template: prompt.template,
                    row: row,
                    columns: columns
                )

                for modelConfig in modelConfigs {
                    let compositeKey = resultKey(
                        promptID: prompt.id,
                        rowID: row.id,
                        modelConfigID: modelConfig.id
                    )

                    let cacheKey = ResponseCache.cacheKey(
                        expandedPrompt: expanded,
                        systemMessage: prompt.systemMessage,
                        modelID: modelConfig.modelID,
                        providerProfileID: modelConfig.providerProfileID,
                        providerBaseURL: modelConfig.providerProfile.normalizedBaseURL,
                        params: modelConfig.parameters
                    )
                    guard let entry = cache.entry(for: cacheKey) else { continue }

                    if var existing = hydratedResults[compositeKey], existing.status == .completed {
                        guard existing.rawResponse?.isEmpty != false,
                              let rawResponse = entry.rawResponse,
                              !rawResponse.isEmpty else { continue }
                        existing.rawResponse = rawResponse
                        hydratedResults[compositeKey] = existing
                        continue
                    }

                    var result = PromptResult(
                        runID: UUID(),
                        rowID: row.id,
                        promptID: prompt.id,
                        modelID: modelConfig.modelID,
                        modelConfigID: modelConfig.id
                    )
                    result.providerProfileID = modelConfig.providerProfileID
                    result.responseText = entry.responseText
                    result.rawResponse = entry.rawResponse
                    result.tokenUsage = entry.tokenUsage
                    result.durationMs = entry.durationMs
                    result.costUSD = entry.costUSD
                    result.finishedAt = entry.cachedAt
                    result.timingSource = .cached
                    result.timingCohortID = entry.timingCohortID
                    result.timingFinishedAt = entry.timingFinishedAt ?? entry.cachedAt
                    result.cosineSimilarity = entry.cosineSimilarity
                    result.rouge1 = entry.rouge1
                    result.rouge2 = entry.rouge2
                    result.rougeL = entry.rougeL
                    result.status = .completed
                    hydratedResults[compositeKey] = result
                }
            }
        }

        guard hydratedResults != results else { return }
        results = hydratedResults
        persistCompletedResultsForActiveFile()
    }

    func clearPersistedCompletedResults(for fileID: UUID) {
        persistedCompletedResultsByFileID.removeValue(forKey: fileID)
        scheduleCompletedResultsSave()
        if activeFileID == fileID, !isActive {
            results = [:]
            runStartedAt = nil
            runState = .idle
        }
    }

    func retryFailed(concurrency: Int, rateLimit: Double, promptID: UUID? = nil) {
        guard let ctx = runContext, !isActive else { return }

        maxConcurrency = max(1, concurrency)
        rateLimiter = RateLimiter(requestsPerSecond: max(1, rateLimit))

        let providerSecrets = ctx.providerSecrets.isEmpty ? readProviderSecrets(for: ctx.modelConfigs) : ctx.providerSecrets
        guard let providerSecrets else { return }
        let columns = ctx.columns
        let maxRetries = ctx.maxRetries

        var promptsByID: [UUID: Prompt] = [:]
        for prompt in ctx.prompts {
            promptsByID[prompt.id] = prompt
        }
        let promptScopedWorkItems = results.values
            .filter { result in
                result.status == .failed && (promptID == nil || result.promptID == promptID)
            }
            .compactMap { result -> (Prompt, Row, ResolvedFileModelConfig)? in
                guard let prompt = promptsByID[result.promptID],
                      let row = ctx.rows.first(where: { $0.id == result.rowID }),
                      let modelConfigID = result.modelConfigID,
                      let config = ctx.modelConfigs.first(where: { $0.id == modelConfigID }) else { return nil }
                return (prompt, row, config)
            }

        guard !promptScopedWorkItems.isEmpty else { return }

        runStartedAt = Date()
        runState = .running(completed: 0, total: promptScopedWorkItems.count)

        runTask = Task {
            await processWorkItems(promptScopedWorkItems, columns: columns,
                                   providerSecrets: providerSecrets, maxRetries: maxRetries)
            if Task.isCancelled { return }
            if case .running(_, let total) = runState {
                runStartedAt = nil
                runState = .completed(total)
                clearSavedState()
            }
        }
    }

    func retryResult(rowID: UUID, promptID: UUID, modelConfigID: UUID) {
        guard let ctx = runContext,
              let prompt = ctx.prompts.first(where: { $0.id == promptID }),
              let row = ctx.rows.first(where: { $0.id == rowID }),
              let config = ctx.modelConfigs.first(where: { $0.id == modelConfigID }) else { return }

        let key = resultKey(promptID: promptID, rowID: rowID, modelConfigID: modelConfigID)
        if var current = results[key] {
            current.status = .inProgress
            results[key] = current
        }

        let expandedPrompt = InterpolationEngine.expand(
            template: prompt.template, row: row, columns: ctx.columns)
        let providerSecrets = ctx.providerSecrets.isEmpty ? readProviderSecrets(for: ctx.modelConfigs) : ctx.providerSecrets
        guard let providerSecrets else { return }
        let maxRetries = ctx.maxRetries

        Task {
            let result = await Self.callService(
                providerSecrets: providerSecrets,
                prompt: expandedPrompt,
                systemMessage: prompt.systemMessage,
                params: config.parameters,
                row: row, promptID: prompt.id, modelConfig: config,
                maxRetries: maxRetries
            )
            if result.status == .completed,
               let text = result.responseText,
               let usage = result.tokenUsage {
                let key = ResponseCache.cacheKey(
                    expandedPrompt: expandedPrompt,
                    systemMessage: prompt.systemMessage,
                    modelID: result.modelID,
                    providerProfileID: config.providerProfileID,
                    providerBaseURL: config.providerProfile.normalizedBaseURL,
                    params: config.parameters)
                ResponseCache.shared.store(
                    entry: CachedEntry(
                        responseText: text,
                        rawResponse: result.rawResponse,
                        tokenUsage: usage,
                        durationMs: result.durationMs ?? 0,
                        costUSD: result.costUSD ?? 0,
                        cosineSimilarity: result.cosineSimilarity ?? 0,
                        rouge1: result.rouge1,
                        rouge2: result.rouge2,
                        rougeL: result.rougeL,
                        cachedAt: Date(),
                        timingCohortID: result.timingCohortID,
                        timingFinishedAt: result.timingFinishedAt ?? result.finishedAt
                    ),
                    for: key)
            }
            results[resultKey(promptID: result.promptID, rowID: result.rowID, modelConfigID: modelConfigID)] = result
            persistCompletedResultsForActiveFile()
        }
    }

    // MARK: - Disk resume

    private func resumeRemaining(ctx: RunContext, completedSoFar: Int, total: Int) {
        let completedKeys = Set(results.filter { $0.value.status == .completed }.keys)
        let remainingItems: [(Prompt, Row, ResolvedFileModelConfig)] = ctx.prompts.flatMap { prompt in
            ctx.rows.flatMap { row in
                ctx.modelConfigs.compactMap { config in
                    let key = resultKey(promptID: prompt.id, rowID: row.id, modelConfigID: config.id)
                    return completedKeys.contains(key) ? nil : (prompt, row, config)
                }
            }
        }

        guard !remainingItems.isEmpty else {
            runStartedAt = nil
            runState = .completed(total)
            clearSavedState()
            return
        }

        // Re-read settings from UserDefaults for concurrency/rate
        let concurrency = UserDefaults.standard.integer(forKey: "quixote.concurrency")
        let rateLimit = UserDefaults.standard.integer(forKey: "quixote.rateLimit")
        maxConcurrency = max(1, concurrency == 0 ? 10 : concurrency)
        rateLimiter = RateLimiter(requestsPerSecond: max(1, Double(rateLimit == 0 ? 10 : rateLimit)))

        guard let providerSecrets = readProviderSecrets(for: ctx.modelConfigs) else { return }

        // Update runContext with fresh credentials from Keychain.
        runContext = RunContext(
            prompts: ctx.prompts, rows: ctx.rows, columns: ctx.columns,
            modelConfigs: ctx.modelConfigs, providerSecrets: providerSecrets, maxRetries: ctx.maxRetries
        )
        activeFileID = ctx.prompts.first?.fileID

        runStartedAt = Date()
        runState = .running(completed: completedSoFar, total: total)
        let columns = ctx.columns
        let maxRetries = ctx.maxRetries

        runTask = Task {
            await processWorkItems(remainingItems, columns: columns,
                                   providerSecrets: providerSecrets, maxRetries: maxRetries)
            if Task.isCancelled { return }
            switch runState {
            case .running(_, let t), .paused(_, let t):
                runStartedAt = nil
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

        runContext = RunContext(
            prompts: snapshot.prompts, rows: snapshot.rows, columns: snapshot.columns,
            modelConfigs: snapshot.modelConfigs, providerSecrets: [:], maxRetries: snapshot.maxRetries
        )
        activeFileID = snapshot.prompts.first?.fileID
        results = snapshot.results
        isRestoredFromDisk = true
        runStartedAt = Date()
        runState = .paused(completed: snapshot.completedCount, total: snapshot.totalCount)
    }

    private func readProviderSecrets(for modelConfigs: [ResolvedFileModelConfig]) -> [String: String]? {
        do {
            var secrets: [String: String] = [:]
            for profile in uniqueProfiles(from: modelConfigs) where profile.requiresAPIKey {
                secrets[profile.id] = try KeychainHelper.readAPIKey(account: profile.keychainAccount)
            }
            return secrets
        } catch {
            runStartedAt = nil
            runState = .failed(error.localizedDescription)
            return nil
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            saveQueueStateNow()
        }
    }

    private func uniqueProfiles(from modelConfigs: [ResolvedFileModelConfig]) -> [ProviderProfile] {
        var seen = Set<String>()
        var profiles: [ProviderProfile] = []
        for config in modelConfigs where !seen.contains(config.providerProfile.id) {
            seen.insert(config.providerProfile.id)
            profiles.append(config.providerProfile)
        }
        return profiles
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
            modelConfigs: ctx.modelConfigs, maxRetries: ctx.maxRetries,
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
        modelConfigs: [ResolvedFileModelConfig],
        providerSecrets: [String: String],
        maxRetries: Int
    ) async {
        let workItems = prompts.flatMap { prompt in
            rows.flatMap { row in
                modelConfigs.map { modelConfig in (prompt, row, modelConfig) }
            }
        }
        await processWorkItems(workItems, columns: columns, providerSecrets: providerSecrets, maxRetries: maxRetries)

        if Task.isCancelled { return }
        switch runState {
        case .running(_, let total), .paused(_, let total):
            runStartedAt = nil
            runState = .completed(total)
            clearSavedState()
        default:
            break
        }
    }

    private func processWorkItems(
        _ workItems: [(Prompt, Row, ResolvedFileModelConfig)],
        columns: [ColumnDef],
        providerSecrets: [String: String],
        maxRetries: Int
    ) async {
        let cache = ResponseCache.shared

        // --- Partition: apply cache hits immediately, collect misses ---
        var misses: [(Prompt, Row, ResolvedFileModelConfig)] = []
        // Map composite key → expandedPrompt for storing results after API calls
        var expandedPrompts: [String: String] = [:]

        for (prompt, row, modelConfig) in workItems {
            let expanded = InterpolationEngine.expand(
                template: prompt.template, row: row, columns: columns)
            let key = ResponseCache.cacheKey(
                expandedPrompt: expanded,
                systemMessage: prompt.systemMessage,
                modelID: modelConfig.modelID,
                providerProfileID: modelConfig.providerProfileID,
                providerBaseURL: modelConfig.providerProfile.normalizedBaseURL,
                params: modelConfig.parameters)

            if let entry = cache.entry(for: key) {
                var result = PromptResult(
                    runID: UUID(),
                    rowID: row.id,
                    promptID: prompt.id,
                    modelID: modelConfig.modelID,
                    modelConfigID: modelConfig.id)
                result.providerProfileID = modelConfig.providerProfileID
                result.responseText = entry.responseText
                result.rawResponse = entry.rawResponse
                result.tokenUsage = entry.tokenUsage
                result.durationMs = entry.durationMs
                result.costUSD = entry.costUSD
                result.finishedAt = Date()
                result.timingSource = .cached
                result.timingCohortID = entry.timingCohortID
                result.timingFinishedAt = entry.timingFinishedAt ?? entry.cachedAt
                result.cosineSimilarity = entry.cosineSimilarity
                result.rouge1 = entry.rouge1
                result.rouge2 = entry.rouge2
                result.rougeL = entry.rougeL
                result.status = .completed
                updateResult(result)
            } else {
                let compositeKey = resultKey(
                    promptID: prompt.id,
                    rowID: row.id,
                    modelConfigID: modelConfig.id)
                expandedPrompts[compositeKey] = expanded
                misses.append((prompt, row, modelConfig))
            }
        }

        guard !misses.isEmpty else { return }

        // --- Dispatch API calls for cache misses ---
        await withTaskGroup(of: PromptResult.self) { group in
            var iterator = misses.makeIterator()
            var active = 0

            while active < maxConcurrency, let (prompt, row, modelConfig) = iterator.next() {
                let compositeKey = resultKey(
                    promptID: prompt.id,
                    rowID: row.id,
                    modelConfigID: modelConfig.id)
                let expanded = expandedPrompts[compositeKey]!
                group.addTask { [modelConfig, prompt, rateLimiter] in
                    try? await rateLimiter.waitForSlot()
                    return await Self.callService(
                        providerSecrets: providerSecrets,
                        prompt: expanded,
                        systemMessage: prompt.systemMessage,
                        params: modelConfig.parameters,
                        row: row, promptID: prompt.id, modelConfig: modelConfig,
                        maxRetries: maxRetries)
                }
                active += 1
            }

            for await result in group {
                // Store completed results in cache
                if result.status == .completed,
                   let modelConfigID = result.modelConfigID,
                   let text = result.responseText,
                   let usage = result.tokenUsage {
                    let compositeKey = resultKey(
                        promptID: result.promptID,
                        rowID: result.rowID,
                        modelConfigID: modelConfigID)
                    if let expanded = expandedPrompts[compositeKey] {
                        guard let workItem = workItems.first(where: {
                            $0.0.id == result.promptID &&
                            $0.1.id == result.rowID &&
                            $0.2.id == modelConfigID
                        }) else {
                            updateResult(result)
                            continue
                        }
                        let key = ResponseCache.cacheKey(
                            expandedPrompt: expanded,
                            systemMessage: workItem.0.systemMessage,
                            modelID: result.modelID,
                            providerProfileID: workItem.2.providerProfileID,
                            providerBaseURL: workItem.2.providerProfile.normalizedBaseURL,
                            params: workItem.2.parameters)
                        cache.store(
                            entry: CachedEntry(
                                responseText: text,
                                rawResponse: result.rawResponse,
                                tokenUsage: usage,
                                durationMs: result.durationMs ?? 0,
                                costUSD: result.costUSD ?? 0,
                                cosineSimilarity: result.cosineSimilarity ?? 0,
                                rouge1: result.rouge1,
                                rouge2: result.rouge2,
                                rougeL: result.rougeL,
                                cachedAt: Date(),
                                timingCohortID: result.timingCohortID,
                                timingFinishedAt: result.timingFinishedAt ?? result.finishedAt),
                            for: key)
                    }
                }

                updateResult(result)

                if let (prompt, row, modelConfig) = iterator.next() {
                    await waitIfPaused()
                    guard !Task.isCancelled else { break }
                    let compositeKey = resultKey(
                        promptID: prompt.id,
                        rowID: row.id,
                        modelConfigID: modelConfig.id)
                    let expanded = expandedPrompts[compositeKey]!
                    group.addTask { [modelConfig, prompt, rateLimiter] in
                        try? await rateLimiter.waitForSlot()
                        return await Self.callService(
                            providerSecrets: providerSecrets,
                            prompt: expanded,
                            systemMessage: prompt.systemMessage,
                            params: modelConfig.parameters,
                            row: row, promptID: prompt.id, modelConfig: modelConfig,
                            maxRetries: maxRetries)
                    }
                }
            }
        }
    }

    private static func analyticsScores(reference: String, candidate: String) -> AnalyticsScores {
        let referenceTokens = tokenize(reference)
        let candidateTokens = tokenize(candidate)

        guard !referenceTokens.isEmpty, !candidateTokens.isEmpty else {
            return AnalyticsScores(cosineSimilarity: 0, rouge1: 0, rouge2: 0, rougeL: 0)
        }

        return AnalyticsScores(
            cosineSimilarity: cosineSimilarity(referenceTokens, candidateTokens),
            rouge1: rougeN(referenceTokens, candidateTokens, n: 1),
            rouge2: rougeN(referenceTokens, candidateTokens, n: 2),
            rougeL: rougeL(referenceTokens, candidateTokens)
        )
    }

    private static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Bag-of-words cosine similarity between two token sequences. Returns 0–1.
    private static func cosineSimilarity(_ reference: [String], _ candidate: [String]) -> Double {
        let referenceFreq = frequencies(reference)
        let candidateFreq = frequencies(candidate)
        let dot = referenceFreq.reduce(0.0) { acc, pair in
            acc + Double(pair.value) * Double(candidateFreq[pair.key] ?? 0)
        }
        let magA = sqrt(referenceFreq.values.reduce(0.0) { $0 + Double($1 * $1) })
        let magB = sqrt(candidateFreq.values.reduce(0.0) { $0 + Double($1 * $1) })
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }

    private static func rougeN(_ reference: [String], _ candidate: [String], n: Int) -> Double {
        let referenceGrams = ngramFrequencies(reference, n: n)
        let candidateGrams = ngramFrequencies(candidate, n: n)
        guard !referenceGrams.isEmpty, !candidateGrams.isEmpty else { return 0 }

        let overlap = referenceGrams.reduce(0) { acc, pair in
            acc + min(pair.value, candidateGrams[pair.key] ?? 0)
        }
        return f1(
            overlap: overlap,
            referenceCount: referenceGrams.values.reduce(0, +),
            candidateCount: candidateGrams.values.reduce(0, +)
        )
    }

    private static func rougeL(_ reference: [String], _ candidate: [String]) -> Double {
        let lcsCount = longestCommonSubsequenceLength(reference, candidate)
        return f1(
            overlap: lcsCount,
            referenceCount: reference.count,
            candidateCount: candidate.count
        )
    }

    private static func frequencies(_ tokens: [String]) -> [String: Int] {
        var freq: [String: Int] = [:]
        for token in tokens {
            freq[token, default: 0] += 1
        }
        return freq
    }

    private static func ngramFrequencies(_ tokens: [String], n: Int) -> [String: Int] {
        guard tokens.count >= n else { return [:] }
        var freq: [String: Int] = [:]
        for index in 0...(tokens.count - n) {
            let gram = tokens[index..<(index + n)].joined(separator: "\u{1F}")
            freq[gram, default: 0] += 1
        }
        return freq
    }

    private static func longestCommonSubsequenceLength(_ a: [String], _ b: [String]) -> Int {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var previous = Array(repeating: 0, count: b.count + 1)
        var current = Array(repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    current[j] = previous[j - 1] + 1
                } else {
                    current[j] = max(previous[j], current[j - 1])
                }
            }
            swap(&previous, &current)
            current = Array(repeating: 0, count: b.count + 1)
        }

        return previous[b.count]
    }

    private static func f1(overlap: Int, referenceCount: Int, candidateCount: Int) -> Double {
        guard overlap > 0, referenceCount > 0, candidateCount > 0 else { return 0 }
        let precision = Double(overlap) / Double(candidateCount)
        let recall = Double(overlap) / Double(referenceCount)
        guard precision + recall > 0 else { return 0 }
        return (2 * precision * recall) / (precision + recall)
    }

    private static func callService(
        providerSecrets: [String: String],
        prompt: String,
        systemMessage: String,
        params: LLMParameters,
        row: Row,
        promptID: UUID,
        modelConfig: ResolvedFileModelConfig,
        maxRetries: Int
    ) async -> PromptResult {
        let runID = UUID()
        var result = PromptResult(
            runID: runID,
            rowID: row.id,
            promptID: promptID,
            modelID: modelConfig.modelID,
            modelConfigID: modelConfig.id)
        result.providerProfileID = modelConfig.providerProfileID
        result.status = .inProgress
        result.timingSource = .live
        result.timingCohortID = runID
        let service = OpenAICompatibleService(
            profile: modelConfig.providerProfile,
            apiKey: providerSecrets[modelConfig.providerProfileID]
        )

        var attempt = 0
        while true {
            do {
                let response = try await service.complete(
                    prompt: prompt,
                    systemMessage: systemMessage,
                    model: modelConfig.model,
                    params: params)
                result.responseText = response.text
                result.rawResponse = response.rawResponse
                result.tokenUsage = response.tokenUsage
                result.durationMs = response.durationMs
                result.costUSD = modelConfig.model.costFor(
                    inputTokens: response.tokenUsage.input,
                    outputTokens: response.tokenUsage.output
                )
                result.finishedAt = Date()
                result.timingFinishedAt = result.finishedAt
                let analytics = analyticsScores(reference: prompt, candidate: response.text)
                result.cosineSimilarity = analytics.cosineSimilarity
                result.rouge1 = analytics.rouge1
                result.rouge2 = analytics.rouge2
                result.rougeL = analytics.rougeL
                result.status = .completed
                return result
            } catch is CancellationError {
                result.finishedAt = Date()
                result.status = .cancelled
                return result
            } catch {
                if attempt < maxRetries, !Task.isCancelled {
                    attempt += 1
                    result.retryCount = attempt
                    continue
                }
                result.responseText = error.localizedDescription
                result.finishedAt = Date()
                result.status = .failed
                return result
            }
        }
    }

    private func updateResult(_ result: PromptResult) {
        guard let modelConfigID = result.modelConfigID else { return }
        results[resultKey(
            promptID: result.promptID,
            rowID: result.rowID,
            modelConfigID: modelConfigID
        )] = result
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
