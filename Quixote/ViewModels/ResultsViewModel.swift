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
    private var rawResults: [String: PromptResult] = [:]  // composite key: "\(rowID)-\(modelID)"

    // MARK: - Update

    func update(
        results: [String: PromptResult],
        prompt: Prompt?,
        models: [ModelConfig]
    ) {
        rawResults = results
        guard let p = prompt, !models.isEmpty else {
            columns = []
            return
        }
        columns = models.map { m in
            ResultColumn(
                id: "\(p.id)-\(m.id)",
                header: "\(p.name) — \(m.displayName)",
                promptID: p.id,
                modelID: m.id
            )
        }
    }

    func clear() {
        rawResults = [:]
        columns = []
    }

    // MARK: - Lookup

    func result(for rowID: UUID, column: ResultColumn) -> PromptResult? {
        let key = "\(rowID.uuidString)-\(column.modelID)"
        guard let r = rawResults[key],
              r.promptID == column.promptID,
              r.modelID == column.modelID else { return nil }
        return r
    }
}
