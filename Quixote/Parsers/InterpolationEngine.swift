import Foundation

/// Expands `{{column_name}}` tokens in prompt text against a row's values.
/// Unknown tokens are left as-is. After interpolation, a structured data block
/// with all column values is appended so the LLM sees the full row context.
enum InterpolationEngine {

    static func expand(template: String, row: Row, columns: [ColumnDef]) -> String {
        var result = expandInline(template, row: row, columns: columns)

        // Append structured data block
        result += "\n\n---\n"
        for column in columns {
            let value = row.values[column.name] ?? ""
            result += "\(column.name): \(value)\n"
        }

        return result
    }

    static func expandSystemMessage(_ systemMessage: String, row: Row, columns: [ColumnDef]) -> String {
        expandInline(systemMessage, row: row, columns: columns)
    }

    /// Returns all {{token}} names found in a template, in order of appearance.
    static func tokens(in template: String) -> [String] {
        let pattern = #"\{\{\s*([^}]+?)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(template.startIndex..., in: template)
        let matches = regex.matches(in: template, range: range)
        var seen = Set<String>()
        var result: [String] = []
        for match in matches {
            if let r = Range(match.range(at: 1), in: template) {
                let name = String(template[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                if seen.insert(name).inserted {
                    result.append(name)
                }
            }
        }
        return result
    }

    static func tokens(systemMessage: String, template: String) -> [String] {
        tokens(in: systemMessage + " " + template)
    }

    static func missingTokens(in tokens: [String], columns: [ColumnDef]) -> [String] {
        let columnNames = Set(columns.map(\.name))
        return tokens.filter { !columnNames.contains($0) }
    }

    /// Preview: expands using the first row of a table, or returns template unchanged if table is empty.
    static func preview(template: String, table: ParsedTable, columns: [ColumnDef]? = nil) -> String {
        guard let row = table.rows.first else { return template }
        return expand(template: template, row: row, columns: columns ?? table.columns)
    }

    private static func expandInline(_ text: String, row: Row, columns: [ColumnDef]) -> String {
        let pattern = #"\{\{\s*([^}]+?)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).reversed()
        var result = text

        for match in matches {
            guard let tokenRange = Range(match.range(at: 1), in: text),
                  let fullRange = Range(match.range(at: 0), in: result) else { continue }
            let token = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard columns.contains(where: { $0.name == token }) else { continue }
            result.replaceSubrange(fullRange, with: row.values[token] ?? "")
        }

        return result
    }
}
