import SwiftUI

struct StatsPanelView: View {
    @ObservedObject var statsVM: StatsViewModel
    let selectedPromptID: UUID?
    let showExtrapolation: Bool
    let extrapolationScale: ExtrapolationScale

    var body: some View {
        if !visibleStats.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Results Summary")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(visibleStats) { stat in
                            StatSummaryCard(
                                stats: stat,
                                showExtrapolation: showExtrapolation,
                                extrapolationScale: extrapolationScale
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .background(.bar)
        }
    }

    private var visibleStats: [StatsViewModel.ModelStats] {
        let filtered = statsVM.stats(for: selectedPromptID)
        return filtered.isEmpty ? statsVM.modelStats : filtered
    }
}

// MARK: - Stat Summary

private struct StatSummaryCard: View {
    let stats: StatsViewModel.ModelStats
    let showExtrapolation: Bool
    let extrapolationScale: ExtrapolationScale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(stats.promptName) - \(stats.modelDisplayName)")
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            HStack(spacing: 10) {
                SummaryMetric(label: costLabel, value: formatCost(displayCost))
                SummaryMetric(label: tokensLabel, value: formatNumber(displayTokens))
                SummaryMetric(label: "Median", value: String(format: "%.2fs", stats.medianDurationSec))
                SummaryMetric(label: "Progress", value: "\(stats.completedRows)/\(stats.totalRows)")
                SummaryMetric(label: "Sim", value: formatSimilarity(stats.medianCosineSimilarity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(minWidth: 420, alignment: .leading)
    }

    private func formatCost(_ value: Double) -> String {
        if value < 0.01 { return "<$0.01" }
        return String(format: "$%.2f", value)
    }

    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formatSimilarity(_ value: Double) -> String {
        guard value > 0 else { return "—" }
        return String(format: "%.3f", value)
    }

    private var displayCost: Double {
        guard showExtrapolation, stats.completedRows > 0 else {
            return stats.totalCostUSD
        }

        return (stats.totalCostUSD / Double(stats.completedRows))
            * Double(extrapolationScale.multiplier)
    }

    private var displayTokens: Int {
        guard showExtrapolation, stats.completedRows > 0 else {
            return stats.totalTokens
        }

        return Int(
            (Double(stats.totalTokens) / Double(stats.completedRows))
            * Double(extrapolationScale.multiplier)
        )
    }

    private var costLabel: String {
        guard showExtrapolation, stats.completedRows > 0 else { return "Cost" }
        return "Cost \(extrapolationScale.displayName)"
    }

    private var tokensLabel: String {
        guard showExtrapolation, stats.completedRows > 0 else { return "Tokens" }
        return "Tok \(extrapolationScale.displayName)"
    }
}

// MARK: - Summary Metric

private struct SummaryMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }
}
