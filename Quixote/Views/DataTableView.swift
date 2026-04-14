import SwiftUI

private enum DataTableMetrics {
    static let sourceColumnMinWidth: CGFloat = 120
    static let sourceColumnMaxWidth: CGFloat = 240
    static let resultColumnMinWidth: CGFloat = 300
    static let resultColumnMaxWidth: CGFloat = 520
}

private enum DataTableScrollTarget {
    static let firstResultColumn = "data-table-first-result-column"
}

struct DataTableView: View {
    @ObservedObject var viewModel: DataPreviewViewModel
    @ObservedObject var results: ResultsViewModel
    let selectedPromptID: UUID?
    var onRetry: ((UUID, UUID, String) -> Void)? = nil

    var body: some View {
        if viewModel.columns.isEmpty {
            ContentUnavailableView(
                "No Data",
                systemImage: "tablecells",
                description: Text("Open a file from the sidebar to preview its contents.")
            )
        } else {
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
                                    .background(row.index % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
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

// MARK: - Header

struct DataHeaderView: View {
    let columns: [ColumnDef]
    let resultColumns: [ResultsViewModel.ResultColumn]

    var body: some View {
        HStack(spacing: 0) {
            // Row index
            Text("#")
                .frame(width: 50, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
            Divider()

            // Result columns
            ForEach(resultColumns) { col in
                resultHeaderColumn(col)
                Divider()
            }

            // Original columns
            ForEach(columns) { column in
                Text(column.name)
                    .frame(
                        minWidth: DataTableMetrics.sourceColumnMinWidth,
                        maxWidth: DataTableMetrics.sourceColumnMaxWidth,
                        alignment: .leading
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Divider()
            }
        }
        .background(.bar)
    }

    @ViewBuilder
    private func resultHeaderColumn(_ col: ResultsViewModel.ResultColumn) -> some View {
        let header = VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
                Text(col.promptName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
            }

            Text(col.modelDisplayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(
            minWidth: DataTableMetrics.resultColumnMinWidth,
            maxWidth: DataTableMetrics.resultColumnMaxWidth,
            alignment: .leading
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .fixedSize(horizontal: false, vertical: true)
        .help(col.header)

        if col.id == resultColumns.first?.id {
            header.id(DataTableScrollTarget.firstResultColumn)
        } else {
            header
        }
    }
}

// MARK: - Row

struct DataRowView: View {
    let row: Row
    let columns: [ColumnDef]
    let resultColumns: [ResultsViewModel.ResultColumn]
    let getResult: (ResultsViewModel.ResultColumn) -> PromptResult?
    var onRetry: ((ResultsViewModel.ResultColumn) -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Row index
            Text("\(row.index + 1)")
                .frame(width: 50, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
            Divider()

            // Result columns
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
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                Divider()
            }

            // Original columns
            ForEach(columns) { column in
                Text(row.values[column.name] ?? "")
                    .frame(
                        minWidth: DataTableMetrics.sourceColumnMinWidth,
                        maxWidth: DataTableMetrics.sourceColumnMaxWidth,
                        alignment: .leading
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .font(.caption)
                    .lineLimit(2)
                Divider()
            }
        }
    }
}

// MARK: - Result cell

struct ResultCell: View {
    let result: PromptResult?
    var onRetry: (() -> Void)? = nil

    var body: some View {
        switch result?.status {
        case .none, .pending:
            Color.clear.frame(height: 20)

        case .inProgress:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Running…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .completed:
            VStack(alignment: .leading, spacing: 4) {
                Text(result?.responseText ?? "")
                    .font(.caption)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let similarity = result?.cosineSimilarity {
                    Text(String(format: "Similarity %.3f", similarity))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

        case .failed:
            VStack(alignment: .leading, spacing: 4) {
                Label(result?.responseText ?? "Error", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                if let retry = onRetry {
                    Button("Retry", action: retry)
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }

        case .cancelled:
            Label("Cancelled", systemImage: "slash.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Pagination

struct PaginationBar: View {
    @ObservedObject var viewModel: DataPreviewViewModel

    var body: some View {
        HStack {
            Text("\(viewModel.totalRowCount) rows")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: viewModel.previousPage) {
                Image(systemName: "chevron.left")
            }
            .disabled(!viewModel.canGoBack)
            .buttonStyle(.plain)

            Text("Page \(viewModel.currentPage + 1) of \(viewModel.pageCount)")
                .font(.caption)
                .monospacedDigit()

            Button(action: viewModel.nextPage) {
                Image(systemName: "chevron.right")
            }
            .disabled(!viewModel.canGoForward)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
