import Foundation

/// Expands `{{column_name}}` tokens in a prompt template against a row's values.
/// Unknown tokens are left as-is. After interpolation, a structured data block
/// with all column values is appended so the LLM sees the full row context.
enum InterpolationEngine {

    static func expand(template: String, row: Row, columns: [ColumnDef]) -> String {
        var result = template

        // Replace all {{column_name}} tokens
        for column in columns {
            let token = "{{\(column.name)}}"
            let value = row.values[column.name] ?? ""
            result = result.replacingOccurrences(of: token, with: value)
        }

        // Append structured data block
        result += "\n\n---\n"
        for column in columns {
            let value = row.values[column.name] ?? ""
            result += "\(column.name): \(value)\n"
        }

        return result
    }

    /// Returns all {{token}} names found in a template, in order of appearance.
    static func tokens(in template: String) -> [String] {
        let pattern = #"\{\{([^}]+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(template.startIndex..., in: template)
        let matches = regex.matches(in: template, range: range)
        var seen = Set<String>()
        var result: [String] = []
        for match in matches {
            if let r = Range(match.range(at: 1), in: template) {
                let name = String(template[r])
                if seen.insert(name).inserted {
                    result.append(name)
                }
            }
        }
        return result
    }

    /// Preview: expands using the first row of a table, or returns template unchanged if table is empty.
    static func preview(template: String, table: ParsedTable, columns: [ColumnDef]? = nil) -> String {
        guard let row = table.rows.first else { return template }
        return expand(template: template, row: row, columns: columns ?? table.columns)
    }
}
