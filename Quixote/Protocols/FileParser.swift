import Foundation

protocol FileParser {
    static var supportedExtensions: Set<String> { get }
    func parse(url: URL) throws -> ParsedTable
}

enum FileParserError: LocalizedError {
    case unreadable(URL)
    case invalidFormat(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let url): return "Could not read file: \(url.lastPathComponent)"
        case .invalidFormat(let detail): return "Invalid file format: \(detail)"
        }
    }
}
