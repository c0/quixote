import Foundation

@MainActor
final class StatsViewModel: ObservableObject {

    /// Stats for a single (prompt, model) combination
    struct ModelStats: Identifiable, Equatable {
        let promptID: UUID
        let promptName: String
        let modelID: String
        let modelDisplayName: String
        let totalCostUSD: Double
        let medianDurationSec: Double
        let totalTokens: Int
        let medianCosineSimilarity: Double
        let completedRows: Int
        let totalRows: Int

        var id: String { "\(promptID)-\(modelID)" }
    }

    @Published private(set) var modelStats: [ModelStats] = []

    // MARK: - Update

    func update(
        results: [String: PromptResult],
        prompts: [Prompt],
        models: [ModelConfig],
        totalRows: Int
    ) {
        guard !prompts.isEmpty, !models.isEmpty else {
            modelStats = []
            return
        }

        modelStats = prompts.flatMap { prompt in
            models.map { model in
                let completed = results.values.filter {
                    $0.promptID == prompt.id && $0.modelID == model.id && $0.status == .completed
                }

                let totalCost = completed.compactMap { $0.costUSD }.reduce(0, +)
                let durations = completed.compactMap { $0.durationMs }.map { Double($0) / 1000.0 }
                let medianDuration = Self.median(durations)
                let tokens = completed.compactMap { $0.tokenUsage?.total }.reduce(0, +)
                let similarities = completed.compactMap { $0.cosineSimilarity }
                let medianSimilarity = Self.median(similarities)

                return ModelStats(
                    promptID: prompt.id,
                    promptName: prompt.name,
                    modelID: model.id,
                    modelDisplayName: model.displayName,
                    totalCostUSD: totalCost,
                    medianDurationSec: medianDuration,
                    totalTokens: tokens,
                    medianCosineSimilarity: medianSimilarity,
                    completedRows: completed.count,
                    totalRows: totalRows
                )
            }
        }
    }

    func clear() {
        modelStats = []
    }

    // MARK: - Helpers

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
