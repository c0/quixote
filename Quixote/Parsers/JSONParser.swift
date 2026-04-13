import Foundation

struct JSONParser: FileParser {
    static let supportedExtensions: Set<String> = ["json"]

    func parse(url: URL) throws -> ParsedTable {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw FileParserError.unreadable(url)
        }

        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw FileParserError.invalidFormat("Malformed JSON")
        }

        guard let records = json as? [[String: Any]] else {
            throw FileParserError.invalidFormat("Expected a top-level array of objects")
        }

        guard !records.isEmpty else { return .empty }

        var columnNames: [String] = []
        var seen = Set<String>()
        for record in records {
            for key in record.keys where seen.insert(key).inserted {
                columnNames.append(key)
            }
        }

        let columns = columnNames.enumerated().map { ColumnDef(name: $0.element, index: $0.offset) }
        let rows = records.enumerated().map { rowIndex, record in
            var values: [String: String] = [:]
            for column in columnNames {
                values[column] = stringify(record[column])
            }
            return Row(index: rowIndex, values: values)
        }

        return ParsedTable(columns: columns, rows: rows)
    }

    private func stringify(_ value: Any?) -> String {
        guard let value else { return "" }

        if value is NSNull {
            return "null"
        }

        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let array as [Any]:
            return compactJSONString(array) ?? ""
        case let object as [String: Any]:
            return compactJSONString(object) ?? ""
        default:
            return String(describing: value)
        }
    }

    private func compactJSONString(_ value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return string
    }
}
