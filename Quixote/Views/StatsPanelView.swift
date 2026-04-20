import SwiftUI

private enum StatsDrawerSection: String, CaseIterable, Identifiable {
    case progress
    case throughput
    case latency
    case tokens
    case cost
    case similarity
    case errors

    var id: String { rawValue }
}

struct StatsPanelView: View {
    @ObservedObject var statsVM: StatsViewModel
    @ObservedObject var processing: ProcessingViewModel
    @ObservedObject var settings: SettingsViewModel
    var onRetryFailed: () -> Void

    @State private var expandedSection: StatsDrawerSection?

    var body: some View {
        if statsVM.overview.totalItems > 0 || processing.isActive {
            VStack(spacing: 0) {
                summaryRail

                if let expandedSection {
                    detailDrawer(for: expandedSection)
                }
            }
            .overlay(alignment: .top) {
                QuixoteRowDivider()
            }
        }
    }

    private var summaryRail: some View {
        HStack(spacing: 0) {
            summaryButton(.progress) { progressSummary }
            railDivider
            summaryButton(.throughput) { throughputSummary }
            railDivider
            summaryButton(.latency) { latencySummary }
            railDivider
            summaryButton(.tokens) { tokensSummary }
            railDivider
            summaryButton(.cost) { costSummary }
            railDivider
            summaryButton(.similarity) { similaritySummary }
            railDivider
            summaryButton(.errors) { errorsSummary }
        }
        .frame(height: 44)
        .background(Color.quixotePanelRaised)
    }

    @ViewBuilder
    private func detailDrawer(for section: StatsDrawerSection) -> some View {
        VStack(spacing: 0) {
            QuixoteRowDivider()

            switch section {
            case .progress:
                StatsTableSection(
                    title: "Progress",
                    headers: ["Prompt", "Model", "Completed", "Failed", "Total", "% Complete"],
                    rows: statsVM.modelStats.map {
                        [
                            .text($0.promptName),
                            .text($0.modelDisplayName),
                            .number(Double($0.completedRows), decimals: 0),
                            .number(Double($0.failedRows), decimals: 0),
                            .number(Double($0.totalRows), decimals: 0),
                            .number($0.totalRows > 0 ? Double($0.completedRows) / Double($0.totalRows) * 100 : nil)
                        ]
                    },
                    numericColumns: [2, 3, 4, 5]
                )
            case .throughput:
                StatsTableSection(
                    title: "Throughput",
                    headers: ["Prompt", "Model", "Completed", "Elapsed", "Current Rows/s", "Lifetime Avg Rows/s"],
                    rows: statsVM.modelStats.map {
                        [
                            .text($0.promptName),
                            .text($0.modelDisplayName),
                            .number(Double($0.completedRows), decimals: 0),
                            .number($0.elapsedSeconds),
                            .number($0.currentRowsPerSecond),
                            .number($0.lifetimeAverageRowsPerSecond)
                        ]
                    },
                    numericColumns: [2, 3, 4, 5]
                )
            case .latency:
                StatsTableSection(
                    title: "Latency",
                    headers: ["Prompt", "Model", "Rows", "P50 ms", "P90 ms", "P99 ms"],
                    rows: statsVM.modelStats.map {
                        [
                            .text($0.promptName),
                            .text($0.modelDisplayName),
                            .number(Double($0.completedRows), decimals: 0),
                            .number($0.p50LatencyMs),
                            .number($0.p90LatencyMs),
                            .number($0.p99LatencyMs)
                        ]
                    },
                    numericColumns: [2, 3, 4, 5]
                )
            case .tokens:
                splitSection(
                    title: "Tokens",
                    leadingCards: [
                        AnyView(StatsBigMetricCard(
                            title: "Input Tokens",
                            value: Self.fullNumber(statsVM.overview.inputTokens, decimals: 0),
                            progress: totalTokenProgress(input: true),
                            fill: Color.quixoteBlueMuted
                        )),
                        AnyView(StatsBigMetricCard(
                            title: "Output Tokens",
                            value: Self.fullNumber(statsVM.overview.outputTokens, decimals: 0),
                            progress: totalTokenProgress(input: false),
                            fill: Color.quixoteGreen
                        ))
                    ],
                    table: AnyView(
                        StatsTableSection(
                            title: "Per Prompt / Model",
                            headers: ["Prompt", "Model", "Rows", "Input", "Output", "Total", "Est 1K In", "Est 1K Out", "Est 1K Total", "Est 1M In", "Est 1M Out", "Est 1M Total"],
                            rows: statsVM.modelStats.map { stat in
                                [
                                    .text(stat.promptName),
                                    .text(stat.modelDisplayName),
                                    .number(Double(stat.completedRows), decimals: 0),
                                    .number(Double(stat.inputTokens), decimals: 0),
                                    .number(Double(stat.outputTokens), decimals: 0),
                                    .number(Double(stat.totalTokens), decimals: 0),
                                    .number(project(stat.inputTokens, completedRows: stat.completedRows, scale: 1_000), decimals: 0),
                                    .number(project(stat.outputTokens, completedRows: stat.completedRows, scale: 1_000), decimals: 0),
                                    .number(project(stat.totalTokens, completedRows: stat.completedRows, scale: 1_000), decimals: 0),
                                    .number(project(stat.inputTokens, completedRows: stat.completedRows, scale: 1_000_000), decimals: 0),
                                    .number(project(stat.outputTokens, completedRows: stat.completedRows, scale: 1_000_000), decimals: 0),
                                    .number(project(stat.totalTokens, completedRows: stat.completedRows, scale: 1_000_000), decimals: 0)
                                ]
                            },
                            numericColumns: Set(2...11)
                        )
                    )
                )
            case .cost:
                splitSection(
                    title: "Cost",
                    leadingCards: [
                        AnyView(StatsBigMetricCard(
                            title: "Input Cost",
                            value: Self.currency(statsVM.modelStats.reduce(0) { $0 + $1.inputCostUSD }),
                            progress: totalCostProgress(input: true),
                            fill: Color.quixoteBlueMuted
                        )),
                        AnyView(StatsBigMetricCard(
                            title: "Output Cost",
                            value: Self.currency(statsVM.modelStats.reduce(0) { $0 + $1.outputCostUSD }),
                            progress: totalCostProgress(input: false),
                            fill: Color.quixoteGreen
                        )),
                        AnyView(StatsBigMetricCard(
                            title: "Running Total",
                            value: Self.currency(statsVM.overview.totalCostUSD),
                            progress: nil,
                            fill: Color.quixoteBlue
                        ))
                    ],
                    table: AnyView(
                        StatsTableSection(
                            title: "Per Prompt / Model",
                            headers: ["Prompt", "Model", "Rows", "Input $", "Output $", "Total $", "Est 1K In", "Est 1K Out", "Est 1K Total", "Est 1M In", "Est 1M Out", "Est 1M Total"],
                            rows: statsVM.modelStats.map { stat in
                                [
                                    .text(stat.promptName),
                                    .text(stat.modelDisplayName),
                                    .number(Double(stat.completedRows), decimals: 0),
                                    .currency(stat.inputCostUSD),
                                    .currency(stat.outputCostUSD),
                                    .currency(stat.totalCostUSD),
                                    .currency(project(stat.inputCostUSD, completedRows: stat.completedRows, scale: 1_000)),
                                    .currency(project(stat.outputCostUSD, completedRows: stat.completedRows, scale: 1_000)),
                                    .currency(project(stat.totalCostUSD, completedRows: stat.completedRows, scale: 1_000)),
                                    .currency(project(stat.inputCostUSD, completedRows: stat.completedRows, scale: 1_000_000)),
                                    .currency(project(stat.outputCostUSD, completedRows: stat.completedRows, scale: 1_000_000)),
                                    .currency(project(stat.totalCostUSD, completedRows: stat.completedRows, scale: 1_000_000))
                                ]
                            },
                            numericColumns: Set(2...11)
                        )
                    )
                )
            case .similarity:
                StatsTableSection(
                    title: "Similarity",
                    headers: similarityHeaders,
                    rows: similarityRows,
                    numericColumns: similarityNumericColumns
                )
            case .errors:
                errorSection
            }
        }
        .background(Color.quixotePanel)
    }

    private var progressSummary: some View {
        HStack(spacing: 10) {
            statusDot

            VStack(alignment: .leading, spacing: 2) {
                Text(statusLabel)
                    .font(Self.monoFont(size: 11, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(statusColor)

                HStack(spacing: 10) {
                    Text("\(Self.fullNumber(statsVM.overview.completedItems, decimals: 0)) / \(Self.fullNumber(statsVM.overview.totalItems, decimals: 0))")
                        .font(Self.monoFont(size: 13, weight: .semibold))
                        .foregroundStyle(Color.quixoteTextPrimary)
                    ThinProgressBar(progress: statsVM.overview.progress, fill: statusProgressColor)
                        .frame(width: 120)
                    Text(Self.percent(statsVM.overview.progress * 100))
                        .font(Self.monoFont(size: 11))
                        .foregroundStyle(Color.quixoteTextSecondary)
                }
            }
        }
    }

    private var throughputSummary: some View {
        SummaryMetricStack(
            label: "Throughput",
            value: statsVM.overview.throughputRowsPerSecond.map(Self.rate) ?? "-",
            unit: "ROWS/S"
        )
    }

    private var latencySummary: some View {
        HStack(spacing: 8) {
            SummaryMetricStack(
                label: "Latency P50 / P90",
                value: latencySummaryValue,
                unit: "MS"
            )
            SparklineView(data: statsVM.overview.latencySeries)
                .frame(width: 56, height: 16)
        }
    }

    private var tokensSummary: some View {
        SummaryMetricStack(
            label: "Tokens In/Out",
            value: "\(Self.abbreviated(statsVM.overview.inputTokens)) / \(Self.abbreviated(statsVM.overview.outputTokens))"
        )
    }

    private var costSummary: some View {
        SummaryMetricStack(
            label: "Cost",
            value: Self.summaryCurrency(statsVM.overview.totalCostUSD)
        )
    }

    private var similaritySummary: some View {
        SummaryMetricStack(
            label: "Similarity",
            value: similaritySummaryValue
        )
    }

    private var errorsSummary: some View {
        SummaryMetricStack(
            label: "Failed",
            value: Self.fullNumber(statsVM.overview.failedItems, decimals: 0),
            tone: statsVM.overview.failedItems > 0 ? .quixoteRed : .quixoteTextPrimary
        )
    }

    private var errorSection: some View {
        VStack(spacing: 14) {
            StatsSectionHeader(title: "Errors", meta: "\(Self.fullNumber(statsVM.errorStats.reduce(0) { $0 + $1.count }, decimals: 0)) total")

            StatsCard {
                if statsVM.errorStats.isEmpty {
                    Text("No errors")
                        .font(Self.monoFont(size: 11))
                        .tracking(1.6)
                        .foregroundStyle(Color.quixoteTextMuted)
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .center)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(statsVM.errorStats.enumerated()), id: \.element.id) { index, stat in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color.quixoteRed)
                                    .frame(width: 8, height: 8)
                                Text(stat.code)
                                    .font(Self.monoFont(size: 11))
                                    .foregroundStyle(Color.quixoteTextPrimary)
                                Spacer(minLength: 12)
                                Text(stat.modelDisplayName)
                                    .font(Self.monoFont(size: 11))
                                    .foregroundStyle(Color.quixoteTextSecondary)
                                Text("×\(Self.fullNumber(stat.count, decimals: 0))")
                                    .font(Self.monoFont(size: 11))
                                    .foregroundStyle(Color.quixoteTextSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)

                            if index < statsVM.errorStats.count - 1 {
                                QuixoteRowDivider()
                            }
                        }

                        QuixoteRowDivider()

                        HStack {
                            Spacer()
                            Button("RETRY FAILED", action: onRetryFailed)
                                .buttonStyle(StatsBorderButtonStyle())
                                .disabled(statsVM.errorStats.isEmpty || processing.isActive)
                                .opacity(statsVM.errorStats.isEmpty || processing.isActive ? 0.45 : 1)
                        }
                        .padding(12)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func splitSection(title: String, leadingCards: [AnyView], table: AnyView) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 18) {
                ForEach(Array(leadingCards.enumerated()), id: \.offset) { _, card in
                    card
                }
            }
            table
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func summaryButton<Content: View>(_ section: StatsDrawerSection, @ViewBuilder content: () -> Content) -> some View {
        Button {
            expandedSection = expandedSection == section ? nil : section
        } label: {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .background(expandedSection == section ? Color.white.opacity(0.03) : Color.clear)
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    private var railDivider: some View {
        Rectangle()
            .fill(Color.quixoteDivider)
            .frame(width: 1, height: 26)
    }

    private var statusLabel: String {
        switch processing.runState {
        case .running: return "RUNNING"
        case .paused: return "PAUSED"
        case .completed: return "COMPLETE"
        case .failed: return "FAILED"
        case .idle: return statsVM.overview.completedItems > 0 ? "COMPLETE" : "IDLE"
        }
    }

    private var statusColor: Color {
        switch processing.runState {
        case .paused: return .quixoteOrange
        case .failed: return .quixoteRed
        case .running: return .quixoteTextPrimary
        case .completed: return .quixoteTextPrimary
        case .idle: return statsVM.overview.failedItems > 0 ? .quixoteRed : .quixoteTextPrimary
        }
    }

    private var statusProgressColor: Color {
        if statsVM.overview.failedItems > 0 { return .quixoteRed }
        switch processing.runState {
        case .paused: return .quixoteOrange
        case .running, .completed: return .quixoteBlue
        case .failed: return .quixoteRed
        case .idle: return .quixoteBlue
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(statusDotColor)
            .frame(width: 10, height: 10)
    }

    private var statusDotColor: Color {
        switch processing.runState {
        case .running, .completed: return .quixoteGreen
        case .paused: return .quixoteOrange
        case .failed: return .quixoteRed
        case .idle: return statsVM.overview.failedItems > 0 ? .quixoteRed : .quixoteTextMuted
        }
    }

    private var latencySummaryValue: String {
        let p50 = statsVM.overview.latencyP50Ms.map(Self.number) ?? "-"
        let p90 = statsVM.overview.latencyP90Ms.map(Self.number) ?? "-"
        return "\(p50) / \(p90)"
    }

    private var similaritySummaryValue: String {
        let cosine = settings.showCosineSimilarity ? statsVM.overview.medianCosine.map(Self.number) : nil
        let rouge = settings.showRougeMetrics ? statsVM.overview.medianRougeL.map(Self.number) : nil
        switch (cosine, rouge) {
        case let (c?, r?): return "\(c) / \(r)"
        case let (c?, nil): return c
        case let (nil, r?): return r
        default: return "-"
        }
    }

    private var similarityHeaders: [String] {
        var headers = ["Prompt", "Model", "Rows"]
        if settings.showCosineSimilarity {
            headers.append("Median Cosine")
        }
        if settings.showRougeMetrics {
            headers += ["Median ROUGE-1", "Median ROUGE-2", "Median ROUGE-L"]
        }
        return headers
    }

    private var similarityRows: [[StatsCellValue]] {
        statsVM.modelStats.map { stat in
            var row: [StatsCellValue] = [
                .text(stat.promptName),
                .text(stat.modelDisplayName),
                .number(Double(stat.completedRows), decimals: 0)
            ]
            if settings.showCosineSimilarity {
                row.append(.number(stat.medianCosine))
            }
            if settings.showRougeMetrics {
                row.append(.number(stat.medianRouge1))
                row.append(.number(stat.medianRouge2))
                row.append(.number(stat.medianRougeL))
            }
            return row
        }
    }

    private var similarityNumericColumns: Set<Int> {
        Set(2..<similarityHeaders.count)
    }

    private func totalTokenProgress(input: Bool) -> Double? {
        let total = statsVM.overview.inputTokens + statsVM.overview.outputTokens
        guard total > 0 else { return nil }
        let value = input ? statsVM.overview.inputTokens : statsVM.overview.outputTokens
        return Double(value) / Double(total)
    }

    private func totalCostProgress(input: Bool) -> Double? {
        let inputCost = statsVM.modelStats.reduce(0) { $0 + $1.inputCostUSD }
        let outputCost = statsVM.modelStats.reduce(0) { $0 + $1.outputCostUSD }
        let total = inputCost + outputCost
        guard total > 0 else { return nil }
        let value = input ? inputCost : outputCost
        return value / total
    }

    private func project<T: BinaryInteger>(_ value: T, completedRows: Int, scale: Double) -> Double? {
        guard completedRows > 0 else { return nil }
        return Double(value) / Double(completedRows) * scale
    }

    private func project(_ value: Double, completedRows: Int, scale: Double) -> Double? {
        guard completedRows > 0 else { return nil }
        return value / Double(completedRows) * scale
    }

    fileprivate static func abbreviated(_ value: Int) -> String {
        abbreviated(Double(value))
    }

    fileprivate static func abbreviated(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if absValue >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return String(format: "%.1f", value)
    }

    fileprivate static func summaryCurrency(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1_000 {
            return "$" + abbreviated(value)
        }
        return currency(value)
    }

    fileprivate static func fullNumber(_ value: Int, decimals: Int = 1) -> String {
        fullNumber(Double(value), decimals: decimals)
    }

    fileprivate static func fullNumber(_ value: Double, decimals: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(decimals)f", value)
    }

    fileprivate static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    fileprivate static func number(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    fileprivate static func rate(_ value: Double) -> String {
        switch abs(value) {
        case ..<0.1 where value != 0:
            return String(format: "%.3f", value)
        case ..<1:
            return String(format: "%.2f", value)
        default:
            return number(value)
        }
    }

    fileprivate static func currency(_ value: Double?) -> String {
        guard let value else { return "-" }
        return formatCurrency(value)
    }

    private static func formatCurrency(_ value: Double) -> String {
        let absValue = abs(value)
        let decimals: Int
        switch absValue {
        case 0:
            decimals = 1
        case 0..<0.01:
            decimals = 5
        case 0.01..<0.1:
            decimals = 4
        case 0.1..<1:
            decimals = 3
        case 1..<100:
            decimals = 2
        default:
            decimals = 1
        }
        return "$" + fullNumber(value, decimals: decimals)
    }

    fileprivate static func monoFont(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .custom("JetBrains Mono", size: size).weight(weight)
    }
}

private enum StatsCellValue {
    case text(String)
    case number(Double?, decimals: Int = 1)
    case currency(Double?)
}

private struct SummaryMetricStack: View {
    let label: String
    let value: String
    var unit: String? = nil
    var tone: Color = .quixoteTextPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.custom("JetBrains Mono", size: 10).weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(Color.quixoteTextMuted)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.custom("JetBrains Mono", size: 14).weight(.semibold))
                    .foregroundStyle(tone)
                    .lineLimit(1)
                if let unit {
                    Text(unit)
                        .font(.custom("JetBrains Mono", size: 10).weight(.medium))
                        .tracking(1.4)
                        .foregroundStyle(Color.quixoteTextMuted)
                }
            }
        }
    }
}

private struct ThinProgressBar: View {
    let progress: Double
    let fill: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                Capsule()
                    .fill(fill)
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
            }
        }
        .frame(height: 4)
    }
}

private struct SparklineView: View {
    let data: [Double]

    var body: some View {
        GeometryReader { proxy in
            if data.count >= 2 {
                Path { path in
                    let minValue = data.min() ?? 0
                    let maxValue = data.max() ?? 1
                    let range = max(maxValue - minValue, 1)

                    for (index, value) in data.enumerated() {
                        let x = proxy.size.width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                        let normalized = (value - minValue) / range
                        let y = proxy.size.height * (1 - CGFloat(normalized))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.quixoteBlueMuted, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct StatsSectionHeader: View {
    let title: String
    let meta: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.custom("Inter Tight", size: 11).weight(.semibold))
                .tracking(2.2)
                .foregroundStyle(Color.quixoteTextSecondary)
            Spacer()
            if let meta {
                Text(meta.uppercased())
                    .font(.custom("JetBrains Mono", size: 10).weight(.medium))
                    .tracking(1.6)
                    .foregroundStyle(Color.quixoteTextMuted)
            }
        }
    }
}

private struct StatsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.quixoteCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.quixoteDivider, lineWidth: 1)
                    )
            )
    }
}

private struct StatsBigMetricCard: View {
    let title: String
    let value: String
    let progress: Double?
    let fill: Color

    var body: some View {
        StatsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title.uppercased())
                    .font(.custom("JetBrains Mono", size: 10).weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.quixoteTextMuted)
                Text(value)
                    .font(.custom("JetBrains Mono", size: 16).weight(.semibold))
                    .foregroundStyle(Color.quixoteTextPrimary)
                if let progress {
                    ThinProgressBar(progress: progress, fill: fill)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        }
    }
}

private struct StatsBorderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.quixoteTextPrimary.opacity(configuration.isPressed ? 0.8 : 1))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.quixoteDivider, lineWidth: 1)
                    )
            )
    }
}

private struct StatsTableSection: View {
    let title: String
    let headers: [String]
    let rows: [[StatsCellValue]]
    let numericColumns: Set<Int>

    var body: some View {
        VStack(spacing: 8) {
            StatsSectionHeader(title: title, meta: nil)

            StatsCard {
                if rows.isEmpty {
                    Text("No data")
                        .font(.custom("JetBrains Mono", size: 11).weight(.medium))
                        .tracking(1.6)
                        .foregroundStyle(Color.quixoteTextMuted)
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .center)
                } else {
                    GeometryReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(spacing: 0) {
                                headerRow
                                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                                    dataRow(row, striped: index.isMultiple(of: 2) == false)
                                }
                            }
                            .frame(minWidth: max(860, proxy.size.width), alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 0, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                Text(header.uppercased())
                    .font(.custom("JetBrains Mono", size: 10).weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color.quixoteTextSecondary)
                    .frame(maxWidth: .infinity, alignment: numericColumns.contains(index) ? .trailing : .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .background(Color.quixotePanelRaised)
        .overlay(alignment: .bottom) { QuixoteRowDivider() }
    }

    private func dataRow(_ row: [StatsCellValue], striped: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                cellView(cell)
                    .frame(maxWidth: .infinity, alignment: numericColumns.contains(index) ? .trailing : .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .background(striped ? Color.quixotePanelRaised.opacity(0.35) : Color.clear)
        .overlay(alignment: .bottom) { QuixoteRowDivider() }
    }

    @ViewBuilder
    private func cellView(_ value: StatsCellValue) -> some View {
        switch value {
        case .text(let text):
            Text(text.isEmpty ? "-" : text)
                .font(.custom("JetBrains Mono", size: 11).weight(.medium))
                .foregroundStyle(text.isEmpty ? Color.quixoteTextMuted : Color.quixoteTextPrimary)
                .lineLimit(1)
        case .number(let number, let decimals):
            Text(number.map { StatsPanelView.fullNumber($0, decimals: decimals) } ?? "-")
                .font(.custom("JetBrains Mono", size: 11).weight(.medium))
                .foregroundStyle(number == nil ? Color.quixoteTextMuted : Color.quixoteTextPrimary)
                .lineLimit(1)
        case .currency(let amount):
            Text(amount.map { StatsPanelView.currency($0) } ?? "-")
                .font(.custom("JetBrains Mono", size: 11).weight(.medium))
                .foregroundStyle(amount == nil ? Color.quixoteTextMuted : Color.quixoteTextPrimary)
                .lineLimit(1)
        }
    }
}
