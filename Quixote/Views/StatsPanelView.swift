import SwiftUI

struct StatsPanelView: View {
    @ObservedObject var statsVM: StatsViewModel

    var body: some View {
        if statsVM.modelStats.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Statistics")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(statsVM.modelStats) { stat in
                            StatCard(stats: stat)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let stats: StatsViewModel.ModelStats

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stats.modelDisplayName)
                .font(.caption.weight(.semibold))

            Divider()

            StatRow(label: "Cost", value: formatCost(stats.totalCostUSD))
            StatRow(label: "Median time", value: String(format: "%.2fs", stats.medianDurationSec))
            StatRow(label: "Total tokens", value: formatNumber(stats.totalTokens))
            StatRow(label: "Similarity", value: formatSimilarity(stats.medianCosineSimilarity))
            StatRow(label: "Progress", value: "\(stats.completedRows)/\(stats.totalRows) rows")
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(minWidth: 160)
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
}

// MARK: - Stat Row

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }
}
