import Foundation

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

    @Published var runState: RunState = .idle
    // Results keyed by composite "\(rowID)-\(modelID)" — supports multi-model
    @Published var results: [String: PromptResult] = [:]

    private var runTask: Task<Void, Never>?
    private var pauseContinuation: CheckedContinuation<Void, Never>?
    private var runContext: RunContext?
    private var maxConcurrency = 2
    private var rateLimiter = RateLimiter(requestsPerSecond: 5)

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

    var progress: Double {
        if case .running(let done, let total) = runState, total > 0 {
            return Double(done) / Double(total)
        }
        return 0
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
        results = [:]
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
    }

    func resume() {
        guard case .paused(let done, let total) = runState else { return }
        runState = .running(completed: done, total: total)
        pauseContinuation?.resume()
        pauseContinuation = nil
    }

    func cancel() {
        pauseContinuation?.resume()
        pauseContinuation = nil
        runTask?.cancel()
        runTask = nil
        for (key, var result) in results {
            if result.status == .pending || result.status == .inProgress {
                result.status = .cancelled
                results[key] = result
            }
        }
        runState = .idle
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
    }

    private func waitIfPaused() async {
        guard isPaused else { return }
        await withCheckedContinuation { continuation in
            pauseContinuation = continuation
        }
    }
}
