import Foundation

struct CSVParser: FileParser {
    static let supportedExtensions: Set<String> = ["csv"]

    func parse(url: URL) throws -> ParsedTable {
        let raw: String
        do {
            // Try UTF-8 first, fall back to system encoding
            if let s = try? String(contentsOf: url, encoding: .utf8) {
                raw = s
            } else if let s = try? String(contentsOf: url, encoding: .isoLatin1) {
                raw = s
            } else {
                throw FileParserError.unreadable(url)
            }
        }

        var lines = splitLines(raw)
        // Drop trailing blank lines
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            lines.removeLast()
        }

        guard !lines.isEmpty else {
            return .empty
        }

        let headerFields = parseCSVLine(lines[0])
        guard !headerFields.isEmpty else {
            throw FileParserError.invalidFormat("No columns found in header row")
        }

        let columns = headerFields.enumerated().map { ColumnDef(name: $0.element, index: $0.offset) }

        var rows: [Row] = []
        for (lineIndex, line) in lines.dropFirst().enumerated() {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let fields = parseCSVLine(line)
            var values: [String: String] = [:]
            for (colIndex, column) in columns.enumerated() {
                values[column.name] = colIndex < fields.count ? fields[colIndex] : ""
            }
            rows.append(Row(index: lineIndex, values: values))
        }

        return ParsedTable(columns: columns, rows: rows)
    }

    // MARK: - Parsing helpers

    private func splitLines(_ text: String) -> [String] {
        // Foundation handles \n, \r\n, \r — rejoin lines inside quoted fields
        let raw = text.components(separatedBy: .newlines)
        var result: [String] = []
        var pending: String? = nil

        for line in raw {
            if var acc = pending {
                acc += "\n" + line
                if quoteCount(acc) % 2 == 0 {
                    result.append(acc)
                    pending = nil
                } else {
                    pending = acc
                }
            } else if quoteCount(line) % 2 == 0 {
                result.append(line)
            } else {
                pending = line
            }
        }
        if let acc = pending { result.append(acc) }
        return result
    }

    private func quoteCount(_ s: String) -> Int {
        s.reduce(0) { $1 == "\"" ? $0 + 1 : $0 }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"" {
                let next = line.index(after: i)
                if inQuotes && next < line.endIndex && line[next] == "\"" {
                    // Escaped quote
                    current.append("\"")
                    i = next
                } else {
                    inQuotes.toggle()
                }
            } else if ch == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }
}
