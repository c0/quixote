import Foundation
import CoreXLSX

struct ExcelParser: FileParser {
    static let supportedExtensions: Set<String> = ["xlsx"]

    func parse(url: URL) throws -> ParsedTable {
        guard let file = XLSXFile(filepath: url.path) else {
            throw FileParserError.unreadable(url)
        }

        let worksheetPaths = try file.parseWorksheetPaths()
        guard let firstWorksheetPath = worksheetPaths.first else {
            throw FileParserError.invalidFormat("Workbook contains no worksheets")
        }

        let worksheet = try file.parseWorksheet(at: firstWorksheetPath)
        let sharedStrings = try file.parseSharedStrings()
        let rows = worksheet.data?.rows ?? []

        let nonEmptyRows = trimTrailingEmptyRows(rows)
        guard let headerRow = nonEmptyRows.first else {
            throw FileParserError.invalidFormat("Worksheet has no header row")
        }

        let headerMap = makeCellMap(for: headerRow, sharedStrings: sharedStrings)
        let orderedColumns = headerMap.keys.sorted()
        let headerNames = orderedColumns.map { columnIndex in
            let value = headerMap[columnIndex]?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            return value.isEmpty ? "Column \(columnIndex + 1)" : value
        }

        guard !headerNames.isEmpty else {
            throw FileParserError.invalidFormat("Worksheet has no header row")
        }

        let columns = headerNames.enumerated().map { ColumnDef(name: $0.element, index: $0.offset) }
        let dataRows = nonEmptyRows.dropFirst().enumerated().map { offset, row -> Row in
            let cellMap = makeCellMap(for: row, sharedStrings: sharedStrings)
            var values: [String: String] = [:]
            for (columnOffset, columnName) in headerNames.enumerated() {
                let columnIndex = orderedColumns[columnOffset]
                values[columnName] = cellMap[columnIndex] ?? ""
            }
            return Row(index: offset, values: values)
        }

        return ParsedTable(columns: columns, rows: dataRows)
    }

    private func trimTrailingEmptyRows(_ rows: [CoreXLSX.Row]) -> [CoreXLSX.Row] {
        var trimmed = rows
        while let last = trimmed.last, isEmpty(row: last) {
            trimmed.removeLast()
        }
        return trimmed
    }

    private func isEmpty(row: CoreXLSX.Row) -> Bool {
        row.cells.allSatisfy { cell in
            let rawValue = stringValue(for: cell, sharedStrings: nil)
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return rawValue.isEmpty
        }
    }

    private func makeCellMap(for row: CoreXLSX.Row, sharedStrings: SharedStrings?) -> [Int: String] {
        var values: [Int: String] = [:]
        for cell in row.cells {
            guard let columnIndex = columnIndex(for: cell) else { continue }
            values[columnIndex] = stringValue(for: cell, sharedStrings: sharedStrings)
        }
        return values
    }

    private func columnIndex(for cell: Cell) -> Int? {
        ColumnReference("A")?.distance(to: cell.reference.column)
    }

    private func stringValue(for cell: Cell, sharedStrings: SharedStrings?) -> String {
        if let sharedStrings, let value = cell.stringValue(sharedStrings) {
            return value
        }
        if let inlineString = cell.inlineString?.text {
            return inlineString
        }
        if let value = cell.value {
            return value
        }
        if let formula = cell.formula?.value {
            return formula
        }
        return ""
    }
}
