import Foundation
import Combine

@MainActor
final class DataPreviewViewModel: ObservableObject {
    static let pageSize = 1000

    @Published private(set) var columns: [ColumnDef] = []
    @Published private(set) var visibleRows: [Row] = []
    @Published private(set) var totalRowCount: Int = 0
    @Published var currentPage: Int = 0

    private var allRows: [Row] = []

    var pageCount: Int {
        max(1, Int(ceil(Double(allRows.count) / Double(Self.pageSize))))
    }

    var canGoBack: Bool { currentPage > 0 }
    var canGoForward: Bool { currentPage < pageCount - 1 }

    func load(table: ParsedTable) {
        columns = table.columns
        allRows = table.rows
        totalRowCount = table.rows.count
        currentPage = 0
        updateVisibleRows()
    }

    func clear() {
        columns = []
        allRows = []
        visibleRows = []
        totalRowCount = 0
        currentPage = 0
    }

    func nextPage() {
        guard canGoForward else { return }
        currentPage += 1
        updateVisibleRows()
    }

    func previousPage() {
        guard canGoBack else { return }
        currentPage -= 1
        updateVisibleRows()
    }

    // MARK: - Internal

    private func updateVisibleRows() {
        let start = currentPage * Self.pageSize
        let end = min(start + Self.pageSize, allRows.count)
        visibleRows = start < allRows.count ? Array(allRows[start..<end]) : []
    }
}
