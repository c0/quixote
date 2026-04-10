import Foundation

struct CSVParser: FileParser {
    // Also handles TSV and semicolon/pipe-delimited files via auto-detection
    static let supportedExtensions: Set<String> = ["csv", "tsv", "tab"]

    func parse(url: URL) throws -> ParsedTable {
        let raw: String
        if let s = try? String(contentsOf: url, encoding: .utf8) {
            raw = s
        } else if let s = try? String(contentsOf: url, encoding: .isoLatin1) {
            raw = s
        } else {
            throw FileParserError.unreadable(url)
        }

        let delimiter = detectDelimiter(raw)

        var lines = splitLines(raw)
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            lines.removeLast()
        }

        guard !lines.isEmpty else { return .empty }

        let headerFields = parseFields(lines[0], delimiter: delimiter)
        guard !headerFields.isEmpty else {
            throw FileParserError.invalidFormat("No columns found in header row")
        }

        let columns = headerFields.enumerated().map { ColumnDef(name: $0.element, index: $0.offset) }

        var rows: [Row] = []
        for (lineIndex, line) in lines.dropFirst().enumerated() {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let fields = parseFields(line, delimiter: delimiter)
            var values: [String: String] = [:]
            for (colIndex, column) in columns.enumerated() {
                values[column.name] = colIndex < fields.count ? fields[colIndex] : ""
            }
            rows.append(Row(index: lineIndex, values: values))
        }

        return ParsedTable(columns: columns, rows: rows)
    }

    // MARK: - Delimiter detection (spec §7.2)

    /// Sniffs the first ~6 data lines to find the most consistent delimiter.
    /// Scores each candidate by variance of per-line field counts;
    /// lower variance + higher count = better. Falls back to comma.
    func detectDelimiter(_ text: String) -> Character {
        let candidates: [Character] = [",", "\t", ";", "|"]
        let sampleLines = text
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .prefix(6)

        guard !sampleLines.isEmpty else { return "," }

        var bestDelimiter: Character = ","
        var bestScore = -1.0

        for delimiter in candidates {
            let counts = sampleLines.map { countUnquoted($0, char: delimiter) }
            guard let first = counts.first, first > 0 else { continue }

            // All lines should have the same count for a consistent delimiter
            let allEqual = counts.allSatisfy { $0 == first }
            // Score: field count (higher = more columns found), penalise inconsistency
            let consistencyBonus: Double = allEqual ? 1.0 : 0.5
            let score = Double(first) * consistencyBonus

            if score > bestScore {
                bestScore = score
                bestDelimiter = delimiter
            }
        }

        return bestDelimiter
    }

    /// Counts unquoted occurrences of `char` in a line.
    private func countUnquoted(_ line: String, char: Character) -> Int {
        var count = 0
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle() }
            else if ch == char && !inQuotes { count += 1 }
        }
        return count
    }

    // MARK: - Line splitting

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

    // MARK: - Field parsing

    private func parseFields(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"" {
                let next = line.index(after: i)
                if inQuotes && next < line.endIndex && line[next] == "\"" {
                    current.append("\"")
                    i = next
                } else {
                    inQuotes.toggle()
                }
            } else if ch == delimiter && !inQuotes {
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
