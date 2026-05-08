import Foundation

@MainActor
final class ResultsViewModel: ObservableObject {

    /// One result column in the table (one per prompt × model combination).
    /// AO-2: multiple columns — one per selected model.
    struct ResultColumn: Identifiable, Equatable {
        let id: String           // "\(promptID)-\(modelConfigID)"
        let header: String       // e.g. "Output — gpt-4o"
        let promptName: String
        let modelDisplayName: String
        let promptID: UUID
        let modelID: String
        let providerProfileID: String
        let modelConfigID: UUID
    }

    @Published private(set) var columns: [ResultColumn] = []
    private var rawResults: [String: PromptResult] = [:]  // composite key: "\(promptID)-\(rowID)-\(modelConfigID)"

    // MARK: - Update

    func update(
        results: [String: PromptResult],
        prompts: [Prompt],
        modelConfigs: [ResolvedFileModelConfig]
    ) {
        rawResults = results
        guard !prompts.isEmpty, !modelConfigs.isEmpty else {
            columns = []
            return
        }

        columns = prompts.flatMap { prompt in
            modelConfigs.map { config in
                ResultColumn(
                    id: "\(prompt.id)-\(config.id.uuidString)",
                    header: "\(prompt.name) — \(config.displayName)",
                    promptName: prompt.name,
                    modelDisplayName: config.displayName,
                    promptID: prompt.id,
                    modelID: config.modelID,
                    providerProfileID: config.providerProfileID,
                    modelConfigID: config.id
                )
            }
        }
    }

    func clear() {
        rawResults = [:]
        columns = []
    }

    func columns(for promptID: UUID?) -> [ResultColumn] {
        guard let promptID else { return columns }
        return columns.filter { $0.promptID == promptID }
    }

    // MARK: - Lookup

    func result(for rowID: UUID, column: ResultColumn) -> PromptResult? {
        let key = "\(column.promptID.uuidString)-\(rowID.uuidString)-\(column.modelConfigID.uuidString)"
        guard let r = rawResults[key],
              r.promptID == column.promptID,
              r.modelID == column.modelID,
              r.providerProfileID == column.providerProfileID,
              r.modelConfigID == column.modelConfigID else { return nil }
        return r
    }
}
