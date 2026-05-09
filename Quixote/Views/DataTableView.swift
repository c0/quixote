import AppKit
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
    static let outputPaneWidth: CGFloat = 380
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
    let prompt: Prompt?
    let modelConfig: ResolvedFileModelConfig?
    let columns: [ColumnDef]
}

private enum OutputDetailTab: String, CaseIterable, Identifiable {
    case content = "Content"
    case request = "Request"
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
    let onOpenSettings: () -> Void
    var onRetry: ((UUID, UUID, UUID) -> Void)? = nil

    @State private var selectedResultCell: SelectedResultCell?
    @State private var outputDetailTab: OutputDetailTab = .content

    var body: some View {
        HStack(spacing: 0) {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if selectedResultContext != nil {
                Rectangle()
                    .fill(Color.quixoteDivider)
                    .frame(width: DataTableMetrics.dividerWidth)

                OutputDetailPane(
                    selection: selectedResultContext,
                    selectedTab: $outputDetailTab,
                    showCosineSimilarity: settings.showCosineSimilarity,
                    showRougeMetrics: settings.showRougeMetrics,
                    onClose: {
                        selectedResultCell = nil
                    },
                    onRetry: selectedRetryAction
                )
                .frame(width: DataTableMetrics.outputPaneWidth, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
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
                modelConfigs: modelConfigs,
                onOpenSettings: onOpenSettings
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
            result: results.result(for: row.id, column: column),
            prompt: prompts.first(where: { $0.id == column.promptID }),
            modelConfig: modelConfigs.first(where: { $0.id == column.modelConfigID }),
            columns: columns
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
            outputDetailTab = .content
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
            .padding(.leading, 10)
            .padding(.trailing, onExpand == nil ? 10 : 34)
            .padding(.vertical, 8)

            if let onExpand {
                Button(action: onExpand) {
                    OutputCellArrowIcon()
                        .stroke(isSelected ? Color.quixoteTextPrimary : Color.quixoteTextSecondary, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .frame(width: 12, height: 12)
                        .frame(width: 18, height: 18)
                        .contentShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Toggle output detail")
                .padding(.top, 7)
                .padding(.trailing, 8)
            }
        }
    }
}

private struct OutputCellArrowIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 12
        let x = { (value: CGFloat) in rect.minX + value * scale }
        let y = { (value: CGFloat) in rect.minY + value * scale }

        var path = Path()
        path.move(to: CGPoint(x: x(3), y: y(9)))
        path.addLine(to: CGPoint(x: x(9), y: y(3)))
        path.move(to: CGPoint(x: x(4), y: y(3)))
        path.addLine(to: CGPoint(x: x(9), y: y(3)))
        path.addLine(to: CGPoint(x: x(9), y: y(8)))
        return path
    }
}

private struct OutputDetailPane: View {
    let selection: SelectedResultContext?
    @Binding var selectedTab: OutputDetailTab
    let showCosineSimilarity: Bool
    let showRougeMetrics: Bool
    let onClose: () -> Void
    var onRetry: (() -> Void)? = nil

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneHeader
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)

            QuixoteRowDivider()

            if let selection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        metadataSection(selection)
                        contentSection(selection)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
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
        .background(Color.quixotePanel)
    }

    private var paneHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("OUTPUT DETAIL")

                Text(selectionTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.quixoteTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            iconButton(systemName: "xmark", help: "Close output detail", action: onClose)
        }
    }

    private var selectionTitle: String {
        guard let selection else { return "Full response" }
        return "Row \(selection.row.index + 1) · \(selection.column.promptName)"
    }

    @ViewBuilder
    private func metadataSection(_ selection: SelectedResultContext) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(selection.column.modelDisplayName)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(Color.quixoteTextSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                ForEach(metricItems(for: selection)) { metric in
                    metricItem(metric)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                sectionLabel("VIEW")
                    .fixedSize(horizontal: true, vertical: false)

                OutputDetailSegmentedControl(selection: $selectedTab)

                Spacer(minLength: 0)
            }
            .padding(.top, 6)
            .overlay(alignment: .top) {
                QuixoteRowDivider()
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(sectionTitle(for: selection))

                ZStack(alignment: .topTrailing) {
                    ScrollView {
                        Text(displayText(for: selection))
                            .font(contentFont)
                            .foregroundStyle(foregroundColor(for: selection))
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                            .padding(.trailing, 24)
                    }
                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)

                    iconButton(
                        systemName: copied ? "circle.fill" : "doc.on.doc",
                        help: copied ? "Copied" : "Copy to clipboard",
                        action: { copyCurrentText(selection) }
                    )
                    .padding(.top, 6)
                    .padding(.trailing, 6)
                }
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.quixoteCard)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.quixoteDivider, lineWidth: 1)
                }

                rowSection(selection)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func rowSection(_ selection: SelectedResultContext) -> some View {
        let items = rowItems(for: selection)

        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("ROW")

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text(item.label)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.quixoteTextSecondary)
                            .frame(width: 104, alignment: .leading)
                            .lineLimit(2)

                        Text(item.value)
                            .font(.system(size: 12))
                            .foregroundStyle(item.isEmpty ? Color.quixoteTextMuted : Color.quixoteTextPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 8)

                    if index < items.count - 1 {
                        QuixoteRowDivider()
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.quixoteCard)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.quixoteDivider, lineWidth: 1)
            }
        }
    }

    private func rowItems(for selection: SelectedResultContext) -> [RowDetailItem] {
        let orderedItems = selection.columns.map { column in
            let rawValue = selection.row.values[column.name] ?? ""
            let isEmpty = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return RowDetailItem(label: column.name, value: isEmpty ? "Empty" : rawValue, isEmpty: isEmpty)
        }

        guard !orderedItems.isEmpty else {
            return selection.row.values.keys.sorted().map { key in
                let rawValue = selection.row.values[key] ?? ""
                let isEmpty = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                return RowDetailItem(label: key, value: isEmpty ? "Empty" : rawValue, isEmpty: isEmpty)
            }
        }

        return orderedItems
    }

    private func displayText(for selection: SelectedResultContext) -> String {
        switch selectedTab {
        case .content:
            return outputText(for: selection)
        case .request:
            return requestText(for: selection)
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

    private func requestText(for selection: SelectedResultContext) -> String {
        if let requestBodyJSON = selection.result?.requestBodyJSON, !requestBodyJSON.isEmpty {
            return requestBodyJSON
        }
        guard let prompt = selection.prompt,
              let modelConfig = selection.modelConfig else {
            return "Request unavailable."
        }

        let expandedPrompt = InterpolationEngine.expand(
            template: prompt.template,
            row: selection.row,
            columns: selection.columns
        )
        let expandedSystemMessage = InterpolationEngine.expandSystemMessage(
            prompt.systemMessage,
            row: selection.row,
            columns: selection.columns
        )
        return ProcessingViewModel.requestBodyJSON(
            prompt: expandedPrompt,
            systemMessage: expandedSystemMessage,
            modelConfig: modelConfig
        ) ?? "Request unavailable."
    }

    private func sectionTitle(for selection: SelectedResultContext) -> String {
        switch selectedTab {
        case .content:
            return selection.result?.status == .failed ? "ERROR" : "CONTENT"
        case .request:
            return "REQUEST"
        case .raw:
            return "RAW"
        }
    }

    private var contentFont: Font {
        switch selectedTab {
        case .content, .request:
            return .system(size: 12, design: .monospaced)
        case .raw:
            return .system(size: 12, design: .monospaced)
        }
    }

    private func foregroundColor(for selection: SelectedResultContext) -> Color {
        switch selectedTab {
        case .content:
            return selection.result?.status == .failed ? .quixoteRed : .quixoteTextPrimary
        case .request:
            return requestText(for: selection) == "Request unavailable." ? .quixoteTextSecondary : .quixoteTextPrimary
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

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 120), spacing: 18, alignment: .leading),
            GridItem(.flexible(minimum: 120), spacing: 18, alignment: .leading)
        ]
    }

    private func metricItems(for selection: SelectedResultContext) -> [MetricItem] {
        var items: [MetricItem] = [
            MetricItem(label: "STATUS", value: statusText(selection.result?.status), accent: selection.result?.status == .completed ? .quixoteGreen : nil)
        ]

        if let usage = selection.result?.tokenUsage {
            items.append(MetricItem(label: "TOKENS", value: "\(usage.total)"))
            items.append(MetricItem(label: "IN", value: "\(usage.input)"))
            items.append(MetricItem(label: "OUT", value: "\(usage.output)"))
        }
        if let cost = selection.result?.costUSD {
            items.append(MetricItem(label: "COST", value: String(format: "$%.4f", cost)))
        }
        if let duration = selection.result?.durationMs {
            items.append(MetricItem(label: "LATENCY", value: "\(duration)", unit: "ms"))
        }
        if let retries = selection.result?.retryCount, retries > 0 {
            items.append(MetricItem(label: "RETRIES", value: "\(retries)"))
        }
        if showCosineSimilarity, let similarity = selection.result?.cosineSimilarity {
            items.append(MetricItem(label: "SIM", value: String(format: "%.3f", similarity)))
        }
        if showRougeMetrics, let rouge1 = selection.result?.rouge1 {
            items.append(MetricItem(label: "R1", value: String(format: "%.3f", rouge1)))
        }
        if showRougeMetrics, let rouge2 = selection.result?.rouge2 {
            items.append(MetricItem(label: "R2", value: String(format: "%.3f", rouge2)))
        }
        if showRougeMetrics, let rougeL = selection.result?.rougeL {
            items.append(MetricItem(label: "RL", value: String(format: "%.3f", rougeL)))
        }

        return items
    }

    private func metricItem(label: String, value: String, unit: String? = nil, accent: Color? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(Color.quixoteTextSecondary)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(accent ?? Color.quixoteTextPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            if let unit {
                Text(unit.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.quixoteTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricItem(_ metric: MetricItem) -> some View {
        metricItem(label: metric.label, value: metric.value, unit: metric.unit, accent: metric.accent)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(1.9)
            .foregroundStyle(Color.quixoteTextSecondary)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func iconButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: systemName == "circle.fill" ? 8 : 12, weight: .medium))
                .foregroundStyle(Color.quixoteTextSecondary)
                .frame(width: 24, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func copyCurrentText(_ selection: SelectedResultContext) {
        let text = displayText(for: selection)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        copied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            copied = false
        }
    }
}

private struct MetricItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var unit: String?
    var accent: Color?
}

private struct RowDetailItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let isEmpty: Bool
}

private struct OutputDetailSegmentedControl: View {
    @Binding var selection: OutputDetailTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(OutputDetailTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(selection == tab ? Color.quixoteTextPrimary : Color.quixoteTextSecondary)
                        .padding(.horizontal, 12)
                        .frame(height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(selection == tab ? Color.quixoteBlue : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.quixotePanel)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.quixoteDivider, lineWidth: 1)
        }
        .fixedSize(horizontal: true, vertical: false)
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
