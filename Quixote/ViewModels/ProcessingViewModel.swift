import Foundation

@MainActor
final class ProcessingViewModel: ObservableObject {

    enum RunState: Equatable {
        case idle
        case running(completed: Int, total: Int)
        case completed(Int)   // total processed
        case failed(String)
    }

    @Published var runState: RunState = .idle
    // Results keyed by rowID — consumed by DataTableView in CP-4
    @Published var results: [UUID: PromptResult] = [:]

    private var runTask: Task<Void, Never>?
    private let maxConcurrency = 2

    var isRunning: Bool {
        if case .running = runState { return true }
        return false
    }

    var progress: Double {
        if case .running(let done, let total) = runState, total > 0 {
            return Double(done) / Double(total)
        }
        return 0
    }

    // MARK: - Start

    func startRun(
        prompt: Prompt,
        rows: [Row],
        columns: [ColumnDef],
        model: ModelConfig,
        apiKey: String
    ) {
        guard !isRunning else { return }
        results = [:]
        runState = .running(completed: 0, total: rows.count)

        let run = ProcessingRun(promptID: prompt.id, modelID: model.id)
        let service = OpenAIService(apiKey: apiKey)

        runTask = Task {
            await processRows(run: run, prompt: prompt, rows: rows,
                              columns: columns, model: model, service: service)
        }
    }

    func cancel() {
        runTask?.cancel()
        runTask = nil
        runState = .idle
        results = [:]
    }

    // MARK: - Processing

    private func processRows(
        run: ProcessingRun,
        prompt: Prompt,
        rows: [Row],
        columns: [ColumnDef],
        model: ModelConfig,
        service: OpenAIService
    ) async {
        await withTaskGroup(of: PromptResult.self) { group in
            var iterator = rows.makeIterator()
            var active = 0

            // Seed up to maxConcurrency
            while active < maxConcurrency, let row = iterator.next() {
                let expandedPrompt = InterpolationEngine.expand(
                    template: prompt.template, row: row, columns: columns)
                group.addTask { [run, model, prompt] in
                    await Self.callService(
                        service: service, prompt: expandedPrompt,
                        run: run, row: row, promptID: prompt.id, model: model)
                }
                active += 1
            }

            // Drain and refill
            for await result in group {
                updateResult(result)
                if let row = iterator.next() {
                    let expandedPrompt = InterpolationEngine.expand(
                        template: prompt.template, row: row, columns: columns)
                    group.addTask { [run, model, prompt] in
                        await Self.callService(
                            service: service, prompt: expandedPrompt,
                            run: run, row: row, promptID: prompt.id, model: model)
                    }
                }
            }
        }

        if case .running(_, let total) = runState {
            runState = .completed(total)
        }
    }

    private static func callService(
        service: OpenAIService,
        prompt: String,
        run: ProcessingRun,
        row: Row,
        promptID: UUID,
        model: ModelConfig
    ) async -> PromptResult {
        var result = PromptResult(
            runID: run.id, rowID: row.id,
            promptID: promptID, modelID: model.id)
        result.status = .inProgress

        do {
            let response = try await service.complete(
                prompt: prompt, model: model, params: LLMParameters())
            result.responseText = response.text
            result.tokenUsage = response.tokenUsage
            result.durationMs = response.durationMs
            result.status = .completed
        } catch is CancellationError {
            result.status = .failed
        } catch {
            result.responseText = error.localizedDescription
            result.status = .failed
        }
        return result
    }

    private func updateResult(_ result: PromptResult) {
        results[result.rowID] = result
        if case .running(let done, let total) = runState {
            runState = .running(completed: done + 1, total: total)
        }
    }
}
