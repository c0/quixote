import Foundation

@MainActor
final class StatsViewModel: ObservableObject {

    struct OverviewStats: Equatable {
        let totalItems: Int
        let completedItems: Int
        let failedItems: Int
        let progress: Double
        let throughputRowsPerSecond: Double?
        let throughputSeries: [Double]
        let latencyP50Ms: Double?
        let latencyP90Ms: Double?
        let latencySeries: [Double]
        let inputTokens: Int
        let outputTokens: Int
        let totalCostUSD: Double
        let medianCosine: Double?
        let medianRougeL: Double?

        static let empty = OverviewStats(
            totalItems: 0,
            completedItems: 0,
            failedItems: 0,
            progress: 0,
            throughputRowsPerSecond: nil,
            throughputSeries: [],
            latencyP50Ms: nil,
            latencyP90Ms: nil,
            latencySeries: [],
            inputTokens: 0,
            outputTokens: 0,
            totalCostUSD: 0,
            medianCosine: nil,
            medianRougeL: nil
        )
    }

    struct ModelStats: Identifiable, Equatable {
        let promptID: UUID
        let promptName: String
        let modelID: String
        let modelConfigID: UUID
        let modelDisplayName: String
        let completedRows: Int
        let failedRows: Int
        let totalRows: Int
        let elapsedSeconds: Double?
        let currentRowsPerSecond: Double?
        let lifetimeAverageRowsPerSecond: Double?
        let p50LatencyMs: Double?
        let p90LatencyMs: Double?
        let p99LatencyMs: Double?
        let inputTokens: Int
        let outputTokens: Int
        let totalTokens: Int
        let inputCostUSD: Double
        let outputCostUSD: Double
        let totalCostUSD: Double
        let medianCosine: Double?
        let medianRouge1: Double?
        let medianRouge2: Double?
        let medianRougeL: Double?

        var id: String { "\(promptID)-\(modelConfigID)" }
    }

    struct ErrorStat: Identifiable, Equatable {
        let code: String
        let modelDisplayName: String
        let count: Int

        var id: String { "\(code)-\(modelDisplayName)" }
    }

    @Published private(set) var overview: OverviewStats = .empty
    @Published private(set) var modelStats: [ModelStats] = []
    @Published private(set) var errorStats: [ErrorStat] = []

    func update(
        results: [String: PromptResult],
        prompts: [Prompt],
        modelConfigs: [ResolvedFileModelConfig],
        rows: [Row],
        runState: ProcessingViewModel.RunState,
        runStartedAt: Date?
    ) {
        let totalRows = rows.count
        guard !prompts.isEmpty, !modelConfigs.isEmpty, totalRows > 0 else {
            clear()
            return
        }

        let activePromptIDs = Set(prompts.map(\.id))
        let activeModelConfigIDs = Set(modelConfigs.map(\.id))
        let activeRowIDs = Set(rows.map(\.id))
        let scopedResults = results.values.filter { result in
            activePromptIDs.contains(result.promptID)
                && result.modelConfigID.map(activeModelConfigIDs.contains) == true
                && activeRowIDs.contains(result.rowID)
        }

        let totalItems = prompts.count * modelConfigs.count * totalRows
        let completedResults = scopedResults.filter { $0.status == .completed }
        let failedResults = scopedResults.filter { $0.status == .failed }
        let allLatencies = completedResults.compactMap { $0.durationMs }.map(Double.init)
        let allCosine = completedResults.compactMap(\.cosineSimilarity)
        let allRougeL = completedResults.compactMap(\.rougeL)

        overview = OverviewStats(
            totalItems: totalItems,
            completedItems: completedResults.count,
            failedItems: failedResults.count,
            progress: totalItems > 0 ? Double(completedResults.count) / Double(totalItems) : 0,
            throughputRowsPerSecond: throughput(
                for: completedResults,
                runStartedAt: runStartedAt,
                runState: runState
            ),
            throughputSeries: throughputSeries(for: completedResults),
            latencyP50Ms: percentile(allLatencies, 0.50),
            latencyP90Ms: percentile(allLatencies, 0.90),
            latencySeries: Array(completedResults
                .sorted { displayTimestamp(for: $0) < displayTimestamp(for: $1) }
                .compactMap { $0.durationMs.map(Double.init) }
                .suffix(24)),
            inputTokens: completedResults.compactMap { $0.tokenUsage?.input }.reduce(0, +),
            outputTokens: completedResults.compactMap { $0.tokenUsage?.output }.reduce(0, +),
            totalCostUSD: completedResults.compactMap(\.costUSD).reduce(0, +),
            medianCosine: optionalMedian(allCosine),
            medianRougeL: optionalMedian(allRougeL)
        )

        modelStats = prompts.flatMap { prompt in
            modelConfigs.map { config in
                buildModelStats(
                    prompt: prompt,
                    config: config,
                    results: scopedResults,
                    totalRows: totalRows
                )
            }
        }

        errorStats = buildErrorStats(results: scopedResults, modelConfigs: modelConfigs)
    }

    func clear() {
        overview = .empty
        modelStats = []
        errorStats = []
    }

    func stats(for promptID: UUID?) -> [ModelStats] {
        guard let promptID else { return modelStats }
        return modelStats.filter { $0.promptID == promptID }
    }

    private func buildModelStats(
        prompt: Prompt,
        config: ResolvedFileModelConfig,
        results: [PromptResult],
        totalRows: Int
    ) -> ModelStats {
        let matching = results.filter {
            $0.promptID == prompt.id && $0.modelConfigID == config.id
        }
        let completed = matching.filter { $0.status == .completed }
        let failed = matching.filter { $0.status == .failed }
        let durations = completed.compactMap { $0.durationMs }.map(Double.init)
        let inputTokens = completed.compactMap { $0.tokenUsage?.input }.reduce(0, +)
        let outputTokens = completed.compactMap { $0.tokenUsage?.output }.reduce(0, +)
        let totalTokens = inputTokens + outputTokens
        let inputCost = completed.compactMap { result -> Double? in
            guard let usage = result.tokenUsage else { return nil }
            return Double(usage.input) / 1_000_000 * config.model.costPerMillionInput
        }.reduce(0, +)
        let outputCost = completed.compactMap { result -> Double? in
            guard let usage = result.tokenUsage else { return nil }
            return Double(usage.output) / 1_000_000 * config.model.costPerMillionOutput
        }.reduce(0, +)
        let totalCost = completed.compactMap(\.costUSD).reduce(0, +)

        return ModelStats(
            promptID: prompt.id,
            promptName: prompt.name,
            modelID: config.modelID,
            modelConfigID: config.id,
            modelDisplayName: config.displayName,
            completedRows: completed.count,
            failedRows: failed.count,
            totalRows: totalRows,
            elapsedSeconds: totalElapsedSeconds(for: completed),
            currentRowsPerSecond: currentRowsPerSecond(for: completed),
            lifetimeAverageRowsPerSecond: lifetimeAverageRowsPerSecond(for: completed),
            p50LatencyMs: percentile(durations, 0.50),
            p90LatencyMs: percentile(durations, 0.90),
            p99LatencyMs: percentile(durations, 0.99),
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            inputCostUSD: inputCost,
            outputCostUSD: outputCost,
            totalCostUSD: totalCost,
            medianCosine: optionalMedian(completed.compactMap(\.cosineSimilarity)),
            medianRouge1: optionalMedian(completed.compactMap(\.rouge1)),
            medianRouge2: optionalMedian(completed.compactMap(\.rouge2)),
            medianRougeL: optionalMedian(completed.compactMap(\.rougeL))
        )
    }

    private func buildErrorStats(
        results: [PromptResult],
        modelConfigs: [ResolvedFileModelConfig]
    ) -> [ErrorStat] {
        let displayNames = Dictionary(uniqueKeysWithValues: modelConfigs.map { ($0.id, $0.displayName) })
        var counts: [String: Int] = [:]

        for result in results where result.status == .failed {
            let code = normalizedErrorCode(for: result.responseText ?? "")
            let modelName = result.modelConfigID.flatMap { displayNames[$0] } ?? result.modelID
            let key = "\(code)|\(modelName)"
            counts[key, default: 0] += 1
        }

        return counts
            .map { key, count in
                let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
                return ErrorStat(code: parts[0], modelDisplayName: parts[1], count: count)
            }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                if $0.code != $1.code { return $0.code < $1.code }
                return $0.modelDisplayName < $1.modelDisplayName
            }
    }

    private func throughput(
        for completedResults: [PromptResult],
        runStartedAt: Date?,
        runState: ProcessingViewModel.RunState
    ) -> Double? {
        guard !completedResults.isEmpty else { return nil }
        if let runStartedAt, case .running = runState {
            let liveResults = completedResults.filter { $0.timingSource != .cached }
            if !liveResults.isEmpty {
                let elapsed = max(Date().timeIntervalSince(runStartedAt), 0.001)
                return Double(liveResults.count) / elapsed
            }
        }

        guard let elapsed = totalElapsedSeconds(for: completedResults), elapsed > 0 else { return nil }
        return Double(completedResults.count) / elapsed
    }

    private func totalElapsedSeconds(for results: [PromptResult]) -> Double? {
        let cohorts = timingCohorts(for: results)
        guard !cohorts.isEmpty else { return durationFallback(for: results) }

        let elapsed = cohorts.compactMap { elapsedSeconds(forCohort: $0) }.reduce(0, +)
        if elapsed > 0 { return elapsed }
        return durationFallback(for: results)
    }

    private func currentRowsPerSecond(for results: [PromptResult]) -> Double? {
        let cohorts = timingCohorts(for: results)
        guard let mostRecentCohort = cohorts.max(by: {
            cohortSortDate(for: $0) < cohortSortDate(for: $1)
        }) else {
            return lifetimeAverageRowsPerSecond(for: results)
        }

        let recent = mostRecentCohort
            .sorted { displayTimestamp(for: $0) < displayTimestamp(for: $1) }
            .suffix(10)
        guard recent.count >= 2 else {
            return lifetimeAverageRowsPerSecond(for: results)
        }

        let timestamps = recent.map(displayTimestamp(for:))
        guard let first = timestamps.first, let last = timestamps.last else {
            return lifetimeAverageRowsPerSecond(for: results)
        }
        let elapsed = last.timeIntervalSince(first)
        guard elapsed > 0 else { return lifetimeAverageRowsPerSecond(for: results) }
        return Double(recent.count) / elapsed
    }

    private func lifetimeAverageRowsPerSecond(for results: [PromptResult]) -> Double? {
        guard let elapsed = totalElapsedSeconds(for: results), elapsed > 0 else { return nil }
        return Double(results.count) / elapsed
    }

    private func throughputSeries(for results: [PromptResult]) -> [Double] {
        let cohorts = timingCohorts(for: results)
            .sorted { cohortSortDate(for: $0) < cohortSortDate(for: $1) }

        let values = cohorts.flatMap(rollingThroughputSeries(forCohort:))
        return Array(values.suffix(24))
    }

    private func rollingThroughputSeries(forCohort results: [PromptResult]) -> [Double] {
        let sorted = results.sorted { displayTimestamp(for: $0) < displayTimestamp(for: $1) }
        guard !sorted.isEmpty else { return [] }

        var points: [Double] = []
        let windowSize = min(6, sorted.count)

        for endIndex in sorted.indices {
            let startIndex = max(0, endIndex - windowSize + 1)
            let window = Array(sorted[startIndex...endIndex])

            let rate: Double?
            if window.count >= 2 {
                let elapsed = displayTimestamp(for: window[window.count - 1])
                    .timeIntervalSince(displayTimestamp(for: window[0]))
                if elapsed > 0 {
                    rate = Double(window.count) / elapsed
                } else {
                    rate = durationRateFallback(for: window)
                }
            } else {
                rate = durationRateFallback(for: window)
            }

            if let rate, rate.isFinite, rate > 0 {
                points.append(rate)
            }
        }

        return points
    }

    private func timingCohorts(for results: [PromptResult]) -> [[PromptResult]] {
        Dictionary(grouping: results) { result in
            result.timingCohortID ?? result.runID
        }.values.map(Array.init)
    }

    private func elapsedSeconds(forCohort results: [PromptResult]) -> Double? {
        let timestamps = results.map(displayTimestamp(for:)).sorted()
        guard let first = timestamps.first, let last = timestamps.last else {
            return durationFallback(for: results)
        }
        let elapsed = last.timeIntervalSince(first)
        if elapsed > 0 { return elapsed }
        return durationFallback(for: results)
    }

    private func displayTimestamp(for result: PromptResult) -> Date {
        result.timingFinishedAt ?? result.finishedAt ?? .distantPast
    }

    private func cohortSortDate(for results: [PromptResult]) -> Date {
        results.map(displayTimestamp(for:)).max() ?? .distantPast
    }

    private func durationFallback(for results: [PromptResult]) -> Double? {
        let totalDurationMs = results.compactMap(\.durationMs).reduce(0, +)
        guard totalDurationMs > 0 else { return nil }
        return Double(totalDurationMs) / 1000.0
    }

    private func durationRateFallback(for results: [PromptResult]) -> Double? {
        guard let elapsed = durationFallback(for: results), elapsed > 0 else { return nil }
        return Double(results.count) / elapsed
    }

    private func normalizedErrorCode(for message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("rate limit") || lower.contains("rate_limited") || lower.contains("429") {
            return "rate_limit"
        }
        if lower.contains("invalid api key") || lower.contains("401") || lower.contains("auth") {
            return "auth"
        }
        if lower.contains("network") || lower.contains("timed out") || lower.contains("offline") {
            return "network"
        }
        if lower.contains("server error") || lower.contains("500") || lower.contains("502") || lower.contains("503") {
            return "server"
        }
        return "unknown"
    }

    private func percentile(_ values: [Double], _ percentile: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = Int(ceil(percentile * Double(sorted.count))) - 1
        let clampedIndex = max(0, min(sorted.count - 1, index))
        return sorted[clampedIndex]
    }

    private func optionalMedian(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
