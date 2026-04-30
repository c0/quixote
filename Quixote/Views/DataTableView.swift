import SwiftUI

private enum DataTableMetrics {
    static let indexColumnWidth: CGFloat = 52
    static let dividerWidth: CGFloat = 1
    static let sourceColumnMinWidth: CGFloat = 122
    static let sourceColumnMaxWidth: CGFloat = 188
    static let singleResultColumnMinWidth: CGFloat = 220
    static let singleResultColumnMaxWidth: CGFloat = 260
    static let multiResultColumnMinWidth: CGFloat = 188
    static let multiResultColumnMaxWidth: CGFloat = 224
    static let outputPaneMinWidth: CGFloat = 320
    static let outputPaneIdealWidth: CGFloat = 380
    static let outputPaneMaxWidth: CGFloat = 520
    static let previewLineLimit: Int = 4
    static let cellHorizontalPadding: CGFloat = 20
}

fileprivate struct SelectedResultCell: Equatable {
    let rowID: UUID
    let columnID: String
}

fileprivate struct SelectedResultContext {
    let row: Row
    let column: ResultsViewModel.ResultColumn
    let result: PromptResult?
}

private enum OutputDetailTab: String, CaseIterable, Identifiable {
    case output = "Output"
    case raw = "Raw"

    var id: String { rawValue }
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

    @State private var selectedResultCell: SelectedResultCell?
    @State private var outputDetailTab: OutputDetailTab = .output

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
        .onAppear(perform: pruneSelection)
        .onChange(of: viewModel.visibleRows.map(\.id)) { pruneSelection() }
        .onChange(of: visibleResultColumns.map(\.id)) { pruneSelection() }
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
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    ScrollViewReader { scrollProxy in
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
                        .onChange(of: selectedResultCell) {
                            scrollSelectionIntoView(using: scrollProxy)
                        }
                    }
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
                            rateLimit: Double(settings.rateLimit),
                            promptID: selectedPromptID
                        )
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if selectedResultContext != nil {
                Rectangle()
                    .fill(Color.quixoteDivider)
                    .frame(width: DataTableMetrics.dividerWidth)

                OutputDetailPane(
                    selection: selectedResultContext,
                    selectedTab: $outputDetailTab,
                    showCosineSimilarity: settings.showCosineSimilarity,
                    showRougeMetrics: settings.showRougeMetrics,
                    onRetry: selectedRetryAction
                )
                .frame(
                    minWidth: DataTableMetrics.outputPaneMinWidth,
                    idealWidth: DataTableMetrics.outputPaneIdealWidth,
                    maxWidth: DataTableMetrics.outputPaneMaxWidth,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var visibleResultColumns: [ResultsViewModel.ResultColumn] {
        let filtered = results.columns(for: selectedPromptID)
        return filtered.isEmpty ? results.columns : filtered
    }

    private var selectedResultContext: SelectedResultContext? {
        guard let selectedResultCell,
              let row = viewModel.visibleRows.first(where: { $0.id == selectedResultCell.rowID }),
              let column = visibleResultColumns.first(where: { $0.id == selectedResultCell.columnID }) else {
            return nil
        }

        return SelectedResultContext(
            row: row,
            column: column,
            result: results.result(for: row.id, column: column)
        )
    }

    private var selectedRetryAction: (() -> Void)? {
        guard let selection = selectedResultContext else { return nil }
        return onRetry.map { retry in
            {
                retry(selection.row.id, selection.column.promptID, selection.column.modelConfigID)
            }
        }
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
            selectedCellID: selectedResultCell,
            cellScrollID: resultCellScrollID,
            getResult: { column in
                results.result(for: row.id, column: column)
            },
            onSelectResult: { column in
                selectResult(rowID: row.id, columnID: column.id)
            },
            onRetry: retryHandler
        )
        .background(row.index.isMultiple(of: 2) ? Color.clear : Color.quixotePanelRaised.opacity(0.45))
    }

    private func selectResult(rowID: UUID, columnID: String) {
        let nextSelection = SelectedResultCell(rowID: rowID, columnID: columnID)
        if selectedResultCell == nextSelection {
            selectedResultCell = nil
        } else {
            selectedResultCell = nextSelection
            outputDetailTab = .output
        }
    }

    private func scrollSelectionIntoView(using scrollProxy: ScrollViewProxy) {
        guard let selectedResultCell else { return }
        let targetID = resultCellScrollID(rowID: selectedResultCell.rowID, columnID: selectedResultCell.columnID)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.18)) {
                scrollProxy.scrollTo(targetID, anchor: .trailing)
            }
        }
    }

    private func resultCellScrollID(rowID: UUID, columnID: String) -> String {
        "result-cell-\(rowID.uuidString)-\(columnID)"
    }

    private func pruneSelection() {
        guard let selectedResultCell else { return }
        let visibleRowIDs = Set(viewModel.visibleRows.map(\.id))
        let visibleColumnIDs = Set(visibleResultColumns.map(\.id))
        guard visibleRowIDs.contains(selectedResultCell.rowID),
              visibleColumnIDs.contains(selectedResultCell.columnID) else {
            self.selectedResultCell = nil
            return
        }
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
        VStack(alignment: .leading, spacing: 4) {
            Text(col.promptName.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.quixoteTextPrimary)
                .lineLimit(1)

            Text(col.modelDisplayName)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.quixoteTextSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: resultColumnWidth, alignment: .leading)
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

private struct DataRowView: View {
    let row: Row
    let columns: [ColumnDef]
    let resultColumns: [ResultsViewModel.ResultColumn]
    let selectedCellID: SelectedResultCell?
    let cellScrollID: (UUID, String) -> String
    let getResult: (ResultsViewModel.ResultColumn) -> PromptResult?
    var onSelectResult: ((ResultsViewModel.ResultColumn) -> Void)? = nil
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
                    isSelected: selectedCellID?.rowID == row.id && selectedCellID?.columnID == col.id,
                    onSelect: { onSelectResult?(col) },
                    onExpand: { onSelectResult?(col) },
                    onRetry: onRetry.map { fn in { fn(col) } }
                )
                .frame(width: resultColumnWidth, alignment: .leading)
                .id(cellScrollID(row.id, col.id))
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
    let isSelected: Bool
    var onSelect: (() -> Void)? = nil
    var onExpand: (() -> Void)? = nil
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch result?.status {
            case .none, .pending:
                Text("—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

            case .inProgress:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                        .tint(Color.quixoteBlue)
                    Text("Running…")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.quixoteTextSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            case .completed:
                previewContent(
                    text: result?.responseText ?? "",
                    color: .quixoteTextPrimary
                )

            case .failed:
                previewContent(
                    text: result?.responseText ?? "Error",
                    color: .quixoteRed,
                    systemImage: "exclamationmark.triangle.fill"
                )

            case .cancelled:
                Label("Cancelled", systemImage: "slash.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.quixoteTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.quixoteBlue.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect?()
        }
    }

    private func previewContent(
        text: String,
        color: Color,
        systemImage: String? = nil
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let systemImage {
                    Label(text, systemImage: systemImage)
                        .labelStyle(.titleAndIcon)
                } else {
                    Text(text)
                }
            }
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(color)
            .lineLimit(DataTableMetrics.previewLineLimit)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            if let onExpand {
                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.quixoteBlueMuted)
                        .padding(.top, 8)
                        .padding(.trailing, 10)
                }
                .buttonStyle(.plain)
                .help("Toggle output detail")
            }
        }
    }
}

private struct OutputDetailPane: View {
    let selection: SelectedResultContext?
    @Binding var selectedTab: OutputDetailTab
    let showCosineSimilarity: Bool
    let showRougeMetrics: Bool
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            QuixoteRowDivider()

            if let selection {
                VStack(alignment: .leading, spacing: 16) {
                    metadataSection(selection)
                    contentSection(selection)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    "Select Output",
                    systemImage: "text.viewfinder",
                    description: Text("Click a result cell to inspect the full response here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.quixotePanelRaised.opacity(0.55))
    }

    private var paneHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("OUTPUT DETAIL")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.quixoteTextSecondary)

            Text(selectionTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.quixoteTextPrimary)
                .lineLimit(2)
        }
    }

    private var selectionTitle: String {
        guard let selection else { return "Full response" }
        return "Row \(selection.row.index + 1) · \(selection.column.promptName)"
    }

    @ViewBuilder
    private func metadataSection(_ selection: SelectedResultContext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selection.column.modelDisplayName)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.quixoteTextSecondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                infoChip(label: "STATUS", value: statusText(selection.result?.status))
                if let usage = selection.result?.tokenUsage {
                    infoChip(label: "TOKENS", value: "\(usage.total)")
                    infoChip(label: "IN", value: "\(usage.input)")
                    infoChip(label: "OUT", value: "\(usage.output)")
                }
                if let cost = selection.result?.costUSD {
                    infoChip(label: "COST", value: String(format: "$%.4f", cost))
                }
                if let duration = selection.result?.durationMs {
                    infoChip(label: "LATENCY", value: "\(duration) ms")
                }
                if let retries = selection.result?.retryCount, retries > 0 {
                    infoChip(label: "RETRIES", value: "\(retries)")
                }
                if showCosineSimilarity, let similarity = selection.result?.cosineSimilarity {
                    infoChip(label: "SIM", value: String(format: "%.3f", similarity))
                }
                if showRougeMetrics, let rouge1 = selection.result?.rouge1 {
                    infoChip(label: "R1", value: String(format: "%.3f", rouge1))
                }
                if showRougeMetrics, let rouge2 = selection.result?.rouge2 {
                    infoChip(label: "R2", value: String(format: "%.3f", rouge2))
                }
                if showRougeMetrics, let rougeL = selection.result?.rougeL {
                    infoChip(label: "RL", value: String(format: "%.3f", rougeL))
                }
            }

            if selection.result?.status == .failed, let onRetry {
                Button("Retry Failed Output", action: onRetry)
                    .buttonStyle(QuixoteSecondaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func contentSection(_ selection: SelectedResultContext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Content", selection: $selectedTab) {
                ForEach(OutputDetailTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                Text(sectionTitle(for: selection))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.quixoteTextSecondary)

                ScrollView {
                    Text(displayText(for: selection))
                        .font(contentFont)
                        .foregroundStyle(foregroundColor(for: selection))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.quixotePanel)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.quixoteDivider, lineWidth: 1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func displayText(for selection: SelectedResultContext) -> String {
        switch selectedTab {
        case .output:
            return outputText(for: selection)
        case .raw:
            return rawText(for: selection)
        }
    }

    private func outputText(for selection: SelectedResultContext) -> String {
        switch selection.result?.status {
        case .none, .pending:
            return "No output yet."
        case .inProgress:
            return "This result is still running."
        case .completed, .failed:
            return selection.result?.responseText ?? ""
        case .cancelled:
            return "This run was cancelled."
        }
    }

    private func rawText(for selection: SelectedResultContext) -> String {
        selection.result?.rawResponse ?? "Raw response unavailable."
    }

    private func sectionTitle(for selection: SelectedResultContext) -> String {
        switch selectedTab {
        case .output:
            return selection.result?.status == .failed ? "Error" : "Output"
        case .raw:
            return "Raw"
        }
    }

    private var contentFont: Font {
        switch selectedTab {
        case .output:
            return .system(size: 12)
        case .raw:
            return .system(size: 11, design: .monospaced)
        }
    }

    private func foregroundColor(for selection: SelectedResultContext) -> Color {
        switch selectedTab {
        case .output:
            return selection.result?.status == .failed ? .quixoteRed : .quixoteTextPrimary
        case .raw:
            return selection.result?.rawResponse == nil ? .quixoteTextSecondary : .quixoteTextPrimary
        }
    }

    private func statusText(_ status: ResultStatus?) -> String {
        switch status {
        case .pending, .none:
            return "Pending"
        case .inProgress:
            return "Running"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }

    private func infoChip(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(Color.quixoteTextSecondary)
            Text(value)
                .foregroundStyle(Color.quixoteTextPrimary)
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.quixotePanel)
        )
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
