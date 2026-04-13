import Foundation

@MainActor
final class ResultsViewModel: ObservableObject {

    /// One result column in the table (one per prompt × model combination).
    /// AO-2: multiple columns — one per selected model.
    struct ResultColumn: Identifiable, Equatable {
        let id: String           // "\(promptID)-\(modelID)"
        let header: String       // e.g. "Output — gpt-4o"
        let promptID: UUID
        let modelID: String
    }

    @Published private(set) var columns: [ResultColumn] = []
    private var rawResults: [String: PromptResult] = [:]  // composite key: "\(promptID)-\(rowID)-\(modelID)"

    // MARK: - Update

    func update(
        results: [String: PromptResult],
        prompts: [Prompt],
        models: [ModelConfig]
    ) {
        rawResults = results
        guard !prompts.isEmpty, !models.isEmpty else {
            columns = []
            return
        }

        columns = prompts.flatMap { prompt in
            models.map { model in
                ResultColumn(
                    id: "\(prompt.id)-\(model.id)",
                    header: "\(prompt.name) — \(model.displayName)",
                    promptID: prompt.id,
                    modelID: model.id
                )
            }
        }
    }

    func clear() {
        rawResults = [:]
        columns = []
    }

    // MARK: - Lookup

    func result(for rowID: UUID, column: ResultColumn) -> PromptResult? {
        let key = "\(column.promptID.uuidString)-\(rowID.uuidString)-\(column.modelID)"
        guard let r = rawResults[key],
              r.promptID == column.promptID,
              r.modelID == column.modelID else { return nil }
        return r
    }
}
