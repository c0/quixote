import Foundation

@MainActor
final class ResultsViewModel: ObservableObject {

    /// One result column in the table (one per prompt × model combination).
    /// CP-4: always exactly 0 or 1 column. AO-1/AO-2 will add more.
    struct ResultColumn: Identifiable, Equatable {
        let id: String           // "\(promptID)-\(modelID)"
        let header: String       // e.g. "Output · gpt-4o-mini"
        let promptID: UUID
        let modelID: String
    }

    @Published private(set) var columns: [ResultColumn] = []
    private var rawResults: [UUID: PromptResult] = [:]

    // MARK: - Update

    func update(
        results: [UUID: PromptResult],
        prompt: Prompt?,
        model: ModelConfig?
    ) {
        rawResults = results
        guard let p = prompt, let m = model else {
            columns = []
            return
        }
        let col = ResultColumn(
            id: "\(p.id)-\(m.id)",
            header: "Output · \(m.displayName)",
            promptID: p.id,
            modelID: m.id
        )
        // Only show the column once results have started arriving
        columns = results.isEmpty ? [] : [col]
    }

    func clear() {
        rawResults = [:]
        columns = []
    }

    // MARK: - Lookup

    func result(for rowID: UUID, column: ResultColumn) -> PromptResult? {
        guard let r = rawResults[rowID], r.promptID == column.promptID else { return nil }
        return r
    }
}
