import SwiftUI

struct DataTableView: View {
    @ObservedObject var viewModel: DataPreviewViewModel

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
                                DataRowView(row: row, columns: viewModel.columns)
                                    .background(row.index % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
                            }
                        } header: {
                            DataHeaderView(columns: viewModel.columns)
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

    var body: some View {
        HStack(spacing: 0) {
            // Row index column
            Text("#")
                .frame(width: 50, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)

            Divider()

            ForEach(columns) { column in
                Text(column.name)
                    .frame(minWidth: 120, maxWidth: 240, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

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

    var body: some View {
        HStack(spacing: 0) {
            Text("\(row.index + 1)")
                .frame(width: 50, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)

            Divider()

            ForEach(columns) { column in
                Text(row.values[column.name] ?? "")
                    .frame(minWidth: 120, maxWidth: 240, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .font(.caption)
                    .lineLimit(2)

                Divider()
            }
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
