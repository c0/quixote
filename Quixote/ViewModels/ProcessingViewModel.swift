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

    @Published var runState: RunState = .idle
    // Results keyed by composite "\(rowID)-\(modelID)" — supports multi-model
    @Published var results: [String: PromptResult] = [:]

    private var runTask: Task<Void, Never>?
    private var pauseContinuation: CheckedContinuation<Void, Never>?
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
        rateLimit: Double = 5
    ) {
        guard !isActive, !models.isEmpty else { return }
        maxConcurrency = max(1, concurrency)
        rateLimiter = RateLimiter(requestsPerSecond: max(1, rateLimit))
        results = [:]
        let total = rows.count * models.count
        runState = .running(completed: 0, total: total)

        let service = OpenAIService(apiKey: apiKey)

        runTask = Task {
            await processRows(prompt: prompt, rows: rows,
                               columns: columns, models: models, service: service)
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

    // MARK: - Processing

    private func processRows(
        prompt: Prompt,
        rows: [Row],
        columns: [ColumnDef],
        models: [ModelConfig],
        service: OpenAIService
    ) async {
        // Cartesian product: each row × each model
        let workItems = rows.flatMap { row in
            models.map { model in (row, model) }
        }

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
                        row: row, promptID: prompt.id, model: model)
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
                            row: row, promptID: prompt.id, model: model)
                    }
                }
            }
        }

        if Task.isCancelled { return }
        switch runState {
        case .running(_, let total), .paused(_, let total):
            runState = .completed(total)
        default:
            break
        }
    }

    private static func callService(
        service: OpenAIService,
        prompt: String,
        params: LLMParameters,
        row: Row,
        promptID: UUID,
        model: ModelConfig
    ) async -> PromptResult {
        let runID = UUID()
        var result = PromptResult(
            runID: runID,
            rowID: row.id,
            promptID: promptID, modelID: model.id)
        result.status = .inProgress

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
        } catch is CancellationError {
            result.status = .cancelled
        } catch {
            result.responseText = error.localizedDescription
            result.status = .failed
        }
        return result
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
