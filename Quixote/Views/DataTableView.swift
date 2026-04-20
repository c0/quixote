import SwiftUI

private enum DataTableMetrics {
    static let indexColumnWidth: CGFloat = 52
    static let dividerWidth: CGFloat = 1
    static let sourceColumnMinWidth: CGFloat = 122
    static let sourceColumnMaxWidth: CGFloat = 188
    static let singleResultColumnMinWidth: CGFloat = 300
    static let singleResultColumnMaxWidth: CGFloat = 460
    static let multiResultColumnMinWidth: CGFloat = 232
    static let multiResultColumnMaxWidth: CGFloat = 320
    static let cellHorizontalPadding: CGFloat = 20
}

struct DataTableView: View {
    @ObservedObject var viewModel: DataPreviewViewModel
    @ObservedObject var results: ResultsViewModel
    @ObservedObject var statsVM: StatsViewModel
    @ObservedObject var processing: ProcessingViewModel
    @ObservedObject var settings: SettingsViewModel
    let selectedPromptID: UUID?
    let datasetName: String
    let datasetSubtitle: String
    let selectedPrompt: Prompt?
    let prompts: [Prompt]
    let rows: [Row]
    let columns: [ColumnDef]
    let modelConfigs: [ResolvedFileModelConfig]
    let canExport: Bool
    let onExport: () -> Void
    var onRetry: ((UUID, UUID, UUID) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            paneHeader
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            QuixoteRowDivider()

            if viewModel.columns.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "tablecells",
                    description: Text("Open a file from the sidebar to preview its contents.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                tableContent
            }
        }
        .background(Color.quixotePanel)
    }

    private var paneHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(datasetName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.quixoteTextPrimary)

                Text(datasetSubtitle.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.quixoteTextSecondary)
            }

            Spacer()

            RunActionControls(
                processing: processing,
                settings: settings,
                selectedPrompt: selectedPrompt,
                prompts: prompts,
                rows: rows,
                columns: columns,
                modelConfigs: modelConfigs
            )

            Button {
                onExport()
            } label: {
                Label("DOWNLOAD", systemImage: "arrow.down.to.line")
            }
            .buttonStyle(QuixoteSecondaryButtonStyle())
            .disabled(!canExport)
            .opacity(canExport ? 1 : 0.45)
        }
    }

    private var tableContent: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        Section {
                            ForEach(viewModel.visibleRows) { row in
                                rowView(for: row)
                            }
                        } header: {
                            DataHeaderView(
                                columns: viewModel.columns,
                                resultColumns: visibleResultColumns
                            )
                        }
                    }
                    .frame(width: max(tableContentWidth, proxy.size.width), alignment: .topLeading)
                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
                }
                .scrollClipDisabled()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()

            if viewModel.pageCount > 1 {
                PaginationBar(viewModel: viewModel)
            }

            StatsPanelView(
                statsVM: statsVM,
                processing: processing,
                settings: settings,
                onRetryFailed: {
                    processing.retryFailed(
                        concurrency: settings.concurrency,
                        rateLimit: Double(settings.rateLimit)
                    )
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var visibleResultColumns: [ResultsViewModel.ResultColumn] {
        let filtered = results.columns(for: selectedPromptID)
        return filtered.isEmpty ? results.columns : filtered
    }

    private var tableContentWidth: CGFloat {
        let dividerCount = 1 + viewModel.columns.count + visibleResultColumns.count
        let indexColumnWidth = DataTableMetrics.indexColumnWidth + DataTableMetrics.cellHorizontalPadding
        let sourceColumnsWidth = CGFloat(viewModel.columns.count) * sourceColumnWidth
        let resultColumnsWidth = CGFloat(visibleResultColumns.count) * resultColumnWidth
        return indexColumnWidth
            + sourceColumnsWidth
            + resultColumnsWidth
            + CGFloat(dividerCount) * DataTableMetrics.dividerWidth
    }

    private var sourceColumnWidth: CGFloat {
        DataTableMetrics.sourceColumnMaxWidth + DataTableMetrics.cellHorizontalPadding
    }

    private var resultColumnWidth: CGFloat {
        let baseWidth = visibleResultColumns.count > 1
            ? DataTableMetrics.multiResultColumnMaxWidth
            : DataTableMetrics.singleResultColumnMaxWidth
        return baseWidth + DataTableMetrics.cellHorizontalPadding
    }

    private func rowView(for row: Row) -> some View {
        let rowColumns = visibleResultColumns
        let retryHandler: ((ResultsViewModel.ResultColumn) -> Void)? = onRetry.map { retry in
            { column in
                retry(row.id, column.promptID, column.modelConfigID)
            }
        }

        return DataRowView(
            row: row,
            columns: viewModel.columns,
            resultColumns: rowColumns,
            showCosineSimilarity: settings.showCosineSimilarity,
            showRougeMetrics: settings.showRougeMetrics,
            getResult: { column in
                results.result(for: row.id, column: column)
            },
            onRetry: retryHandler
        )
        .background(row.index.isMultiple(of: 2) ? Color.clear : Color.quixotePanelRaised.opacity(0.45))
    }
}

struct DataHeaderView: View {
    let columns: [ColumnDef]
    let resultColumns: [ResultsViewModel.ResultColumn]

    var body: some View {
        HStack(spacing: 0) {
            headerCell(
                "#",
                width: DataTableMetrics.indexColumnWidth + DataTableMetrics.cellHorizontalPadding,
                alignment: .trailing
            )
            gridDivider

            ForEach(columns) { column in
                headerCell(
                    column.name.uppercased(),
                    width: sourceColumnWidth
                )
                gridDivider
            }

            ForEach(resultColumns) { col in
                resultHeaderColumn(col)
                gridDivider
            }
        }
        .background(Color.quixotePanelRaised)
    }

    private func headerCell(
        _ text: String,
        width: CGFloat? = nil,
        alignment: Alignment = .leading
    ) -> some View {
        Text(text)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(width: width, alignment: alignment)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Color.quixoteTextSecondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private func resultHeaderColumn(_ col: ResultsViewModel.ResultColumn) -> some View {
        let header = VStack(alignment: .leading, spacing: 3) {
            Text(col.promptName.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.quixoteTextPrimary)
                .lineLimit(1)

            Text(col.modelDisplayName)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.quixoteTextSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: resultColumnWidth, alignment: .leading)

        header
    }

    private var gridDivider: some View {
        Rectangle()
            .fill(Color.quixoteDivider)
            .frame(width: DataTableMetrics.dividerWidth)
    }

    private var sourceColumnWidth: CGFloat {
        DataTableMetrics.sourceColumnMaxWidth + DataTableMetrics.cellHorizontalPadding
    }

    private var resultColumnWidth: CGFloat {
        let baseWidth = resultColumns.count > 1
            ? DataTableMetrics.multiResultColumnMaxWidth
            : DataTableMetrics.singleResultColumnMaxWidth
        return baseWidth + DataTableMetrics.cellHorizontalPadding
    }
}

struct DataRowView: View {
    let row: Row
    let columns: [ColumnDef]
    let resultColumns: [ResultsViewModel.ResultColumn]
    let showCosineSimilarity: Bool
    let showRougeMetrics: Bool
    let getResult: (ResultsViewModel.ResultColumn) -> PromptResult?
    var onRetry: ((ResultsViewModel.ResultColumn) -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            Text("\(row.index + 1)")
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(width: DataTableMetrics.indexColumnWidth + DataTableMetrics.cellHorizontalPadding, alignment: .trailing)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.quixoteTextMuted)
            gridDivider

            ForEach(columns) { column in
                SourceCell(value: row.values[column.name] ?? "")
                    .frame(width: sourceColumnWidth, alignment: .leading)
                gridDivider
            }

            ForEach(resultColumns) { col in
                ResultCell(
                    result: getResult(col),
                    showCosineSimilarity: showCosineSimilarity,
                    showRougeMetrics: showRougeMetrics,
                    onRetry: onRetry.map { fn in { fn(col) } }
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(width: resultColumnWidth, alignment: .leading)
                gridDivider
            }
        }
        .overlay(alignment: .bottom) {
            QuixoteRowDivider()
        }
    }

    private var gridDivider: some View {
        Rectangle()
            .fill(Color.quixoteDivider)
            .frame(width: DataTableMetrics.dividerWidth)
    }

    private var sourceColumnWidth: CGFloat {
        DataTableMetrics.sourceColumnMaxWidth + DataTableMetrics.cellHorizontalPadding
    }

    private var resultColumnWidth: CGFloat {
        let baseWidth = resultColumns.count > 1
            ? DataTableMetrics.multiResultColumnMaxWidth
            : DataTableMetrics.singleResultColumnMaxWidth
        return baseWidth + DataTableMetrics.cellHorizontalPadding
    }
}

private struct SourceCell: View {
    let value: String

    var body: some View {
        Text(value)
            .font(font)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    private var font: Font {
        if isNumberLike || isBoolean {
            return .system(size: 11, design: .monospaced)
        }
        return .system(size: 11, weight: .regular)
    }

    private var foreground: Color {
        if isBoolean { return .quixoteBlueMuted }
        return .quixoteTextPrimary
    }

    private var isBoolean: Bool {
        let lower = value.lowercased()
        return lower == "true" || lower == "false"
    }

    private var isNumberLike: Bool {
        Double(value) != nil
    }
}

struct ResultCell: View {
    let result: PromptResult?
    let showCosineSimilarity: Bool
    let showRougeMetrics: Bool
    var onRetry: (() -> Void)? = nil

    var body: some View {
        switch result?.status {
        case .none, .pending:
            Text("—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.quixoteTextMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .inProgress:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                    .tint(Color.quixoteBlue)
                Text("Running…")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextSecondary)
            }

        case .completed:
            VStack(alignment: .leading, spacing: 3) {
                Text(result?.responseText ?? "")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.quixoteTextPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showCosineSimilarity || showRougeMetrics {
                    metricBadges
                }
            }

        case .failed:
            VStack(alignment: .leading, spacing: 6) {
                Label(result?.responseText ?? "Error", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.quixoteRed)
                    .lineLimit(2)
                if let retry = onRetry {
                    Button("Retry", action: retry)
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(Color.quixoteBlueMuted)
                }
            }

        case .cancelled:
            Label("Cancelled", systemImage: "slash.circle")
                .font(.system(size: 12))
                .foregroundStyle(Color.quixoteTextSecondary)
        }
    }

    @ViewBuilder
    private var metricBadges: some View {
        HStack(spacing: 8) {
            if showCosineSimilarity, let similarity = result?.cosineSimilarity {
                metricBadge(label: "SIM", value: similarity)
            }
            if showRougeMetrics, let rouge1 = result?.rouge1 {
                metricBadge(label: "R1", value: rouge1)
            }
            if showRougeMetrics, let rouge2 = result?.rouge2 {
                metricBadge(label: "R2", value: rouge2)
            }
            if showRougeMetrics, let rougeL = result?.rougeL {
                metricBadge(label: "RL", value: rougeL)
            }
        }
        .lineLimit(1)
    }

    private func metricBadge(label: String, value: Double) -> some View {
        Text("\(label) \(String(format: "%.3f", value))")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Color.quixoteTextSecondary)
    }
}

struct PaginationBar: View {
    @ObservedObject var viewModel: DataPreviewViewModel

    var body: some View {
        HStack {
            Text("\(viewModel.totalRowCount) rows")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.quixoteTextSecondary)

            Spacer()

            Button(action: viewModel.previousPage) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.quixoteTextSecondary)
            .disabled(!viewModel.canGoBack)

            Text("Page \(viewModel.currentPage + 1) / \(viewModel.pageCount)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.quixoteTextSecondary)

            Button(action: viewModel.nextPage) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.quixoteTextSecondary)
            .disabled(!viewModel.canGoForward)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.quixotePanelRaised)
        .overlay(alignment: .top) {
            QuixoteRowDivider()
        }
    }
}
