import Foundation

struct CSVParser: FileParser {
    static let supportedExtensions: Set<String> = ["csv"]

    func parse(url: URL) throws -> ParsedTable {
        let raw: String
        do {
            raw = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw FileParserError.unreadable(url)
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
        // Split on CRLF or LF, preserving quoted newlines
        var lines: [String] = []
        var current = ""
        var inQuotes = false
        var i = text.startIndex

        while i < text.endIndex {
            let ch = text[i]
            if ch == "\"" {
                inQuotes.toggle()
                current.append(ch)
            } else if ch == "\r" {
                let next = text.index(after: i)
                if !inQuotes {
                    lines.append(current)
                    current = ""
                    if next < text.endIndex && text[next] == "\n" {
                        i = next
                    }
                } else {
                    current.append(ch)
                }
            } else if ch == "\n" && !inQuotes {
                lines.append(current)
                current = ""
            } else {
                current.append(ch)
            }
            i = text.index(after: i)
        }
        if !current.isEmpty {
            lines.append(current)
        }
        return lines
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
