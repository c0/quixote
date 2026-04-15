import SwiftUI

private enum DataTableMetrics {
    static let sourceColumnMinWidth: CGFloat = 138
    static let sourceColumnMaxWidth: CGFloat = 220
    static let resultColumnMinWidth: CGFloat = 300
    static let resultColumnMaxWidth: CGFloat = 460
}

private enum DataTableScrollTarget {
    static let firstResultColumn = "data-table-first-result-column"
}

struct DataTableView: View {
    @ObservedObject var viewModel: DataPreviewViewModel
    @ObservedObject var results: ResultsViewModel
    let selectedPromptID: UUID?
    let datasetName: String
    let datasetSubtitle: String
    let canExport: Bool
    let onExport: () -> Void
    var onRetry: ((UUID, UUID, String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            paneHeader
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

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
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(datasetName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.quixoteTextPrimary)

                Text(datasetSubtitle.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.quixoteTextSecondary)
            }

            Spacer()

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
            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        Section {
                            ForEach(viewModel.visibleRows) { row in
                                DataRowView(
                                    row: row,
                                    columns: viewModel.columns,
                                    resultColumns: visibleResultColumns,
                                    getResult: { results.result(for: row.id, column: $0) },
                                    onRetry: { col in onRetry?(row.id, col.promptID, col.modelID) }
                                )
                                .background(row.index % 2 == 0 ? Color.clear : Color.quixotePanelRaised.opacity(0.45))
                            }
                        } header: {
                            DataHeaderView(
                                columns: viewModel.columns,
                                resultColumns: visibleResultColumns
                            )
                        }
                    }
                }
                .onAppear {
                    scrollToResults(in: proxy)
                }
                .onChange(of: visibleResultColumns.map(\.id)) {
                    scrollToResults(in: proxy)
                }
            }

            if viewModel.pageCount > 1 {
                PaginationBar(viewModel: viewModel)
            }
        }
    }

    private var visibleResultColumns: [ResultsViewModel.ResultColumn] {
        let filtered = results.columns(for: selectedPromptID)
        return filtered.isEmpty ? results.columns : filtered
    }

    private func scrollToResults(in proxy: ScrollViewProxy) {
        guard !visibleResultColumns.isEmpty else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(DataTableScrollTarget.firstResultColumn, anchor: .leading)
            }
        }
    }
}

struct DataHeaderView: View {
    let columns: [ColumnDef]
    let resultColumns: [ResultsViewModel.ResultColumn]

    var body: some View {
        HStack(spacing: 0) {
            headerCell("#", width: 52, alignment: .trailing)
            gridDivider

            ForEach(columns) { column in
                headerCell(
                    column.name.uppercased(),
                    minWidth: DataTableMetrics.sourceColumnMinWidth,
                    maxWidth: DataTableMetrics.sourceColumnMaxWidth
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
        minWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        alignment: Alignment = .leading
    ) -> some View {
        Text(text)
            .frame(width: width, alignment: alignment)
            .frame(minWidth: minWidth, maxWidth: maxWidth, alignment: alignment)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Color.quixoteTextSecondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private func resultHeaderColumn(_ col: ResultsViewModel.ResultColumn) -> some View {
        let header = VStack(alignment: .leading, spacing: 4) {
            Text(col.promptName.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.quixoteTextPrimary)
                .lineLimit(1)

            Text(col.modelDisplayName)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.quixoteTextSecondary)
                .lineLimit(1)
        }
        .frame(
            minWidth: DataTableMetrics.resultColumnMinWidth,
            maxWidth: DataTableMetrics.resultColumnMaxWidth,
            alignment: .leading
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 10)

        if col.id == resultColumns.first?.id {
            header.id(DataTableScrollTarget.firstResultColumn)
        } else {
            header
        }
    }

    private var gridDivider: some View {
        Rectangle()
            .fill(Color.quixoteDivider)
            .frame(width: 1)
    }
}

struct DataRowView: View {
    let row: Row
    let columns: [ColumnDef]
    let resultColumns: [ResultsViewModel.ResultColumn]
    let getResult: (ResultsViewModel.ResultColumn) -> PromptResult?
    var onRetry: ((ResultsViewModel.ResultColumn) -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            Text("\(row.index + 1)")
                .frame(width: 52, alignment: .trailing)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.quixoteTextMuted)
            gridDivider

            ForEach(columns) { column in
                SourceCell(value: row.values[column.name] ?? "")
                    .frame(
                        minWidth: DataTableMetrics.sourceColumnMinWidth,
                        maxWidth: DataTableMetrics.sourceColumnMaxWidth,
                        alignment: .leading
                    )
                gridDivider
            }

            ForEach(resultColumns) { col in
                ResultCell(
                    result: getResult(col),
                    onRetry: onRetry.map { fn in { fn(col) } }
                )
                .frame(
                    minWidth: DataTableMetrics.resultColumnMinWidth,
                    maxWidth: DataTableMetrics.resultColumnMaxWidth,
                    alignment: .leading
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
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
            .frame(width: 1)
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
            .padding(.vertical, 10)
    }

    private var font: Font {
        if isNumberLike || isBoolean {
            return .system(size: 12, design: .monospaced)
        }
        return .system(size: 12, weight: .medium)
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
    var onRetry: (() -> Void)? = nil

    var body: some View {
        switch result?.status {
        case .none, .pending:
            Text("—")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.quixoteTextMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .inProgress:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                    .tint(Color.quixoteBlue)
                Text("Running…")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextSecondary)
            }

        case .completed:
            VStack(alignment: .leading, spacing: 4) {
                Text(result?.responseText ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.quixoteTextPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let similarity = result?.cosineSimilarity {
                    Text(String(format: "SIM %.3f", similarity))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.quixoteTextSecondary)
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
