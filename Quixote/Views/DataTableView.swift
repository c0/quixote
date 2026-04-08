import SwiftUI

struct DataTableView: View {
    @ObservedObject var viewModel: DataPreviewViewModel
    @ObservedObject var results: ResultsViewModel

    var body: some View {
        if viewModel.columns.isEmpty {
            ContentUnavailableView(
                "No Data",
                systemImage: "tablecells",
                description: Text("Open a file from the sidebar to preview its contents.")
            )
        } else {
            VStack(spacing: 0) {
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        Section {
                            ForEach(viewModel.visibleRows) { row in
                                DataRowView(
                                    row: row,
                                    columns: viewModel.columns,
                                    resultColumns: results.columns,
                                    getResult: { results.result(for: row.id, column: $0) }
                                )
                                .background(row.index % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
                            }
                        } header: {
                            DataHeaderView(
                                columns: viewModel.columns,
                                resultColumns: results.columns
                            )
                        }
                    }
                }

                if viewModel.pageCount > 1 {
                    PaginationBar(viewModel: viewModel)
                }
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

            // Original columns
            ForEach(columns) { column in
                Text(column.name)
                    .frame(minWidth: 120, maxWidth: 240, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Divider()
            }

            // Result columns
            ForEach(resultColumns) { col in
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.accentColor)
                    Text(col.header)
                }
                .frame(minWidth: 240, maxWidth: 400, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .font(.caption.weight(.semibold))
                Divider()
            }
        }
        .background(.bar)
    }
}

// MARK: - Row

struct DataRowView: View {
    let row: Row
    let columns: [ColumnDef]
    let resultColumns: [ResultsViewModel.ResultColumn]
    let getResult: (ResultsViewModel.ResultColumn) -> PromptResult?

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

            // Original columns
            ForEach(columns) { column in
                Text(row.values[column.name] ?? "")
                    .frame(minWidth: 120, maxWidth: 240, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .font(.caption)
                    .lineLimit(2)
                Divider()
            }

            // Result columns
            ForEach(resultColumns) { col in
                ResultCell(result: getResult(col))
                    .frame(minWidth: 240, maxWidth: 400, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                Divider()
            }
        }
    }
}

// MARK: - Result cell

struct ResultCell: View {
    let result: PromptResult?

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
            Text(result?.responseText ?? "")
                .font(.caption)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .failed:
            Label(result?.responseText ?? "Error", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
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
