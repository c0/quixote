import Foundation

// MARK: - FileType

enum FileType: String, Codable, CaseIterable {
    case csv
    case unknown

    static func detect(from url: URL) -> FileType {
        switch url.pathExtension.lowercased() {
        case "csv": return .csv
        default: return .unknown
        }
    }
}

// MARK: - WorkspaceFile

struct WorkspaceFile: Identifiable, Codable, Equatable {
    let id: UUID
    var url: URL
    var displayName: String
    var fileType: FileType
    var addedAt: Date
    var contentHash: String

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.displayName = url.deletingPathExtension().lastPathComponent
        self.fileType = FileType.detect(from: url)
        self.addedAt = Date()
        self.contentHash = ""
    }
}

// MARK: - ColumnDef

struct ColumnDef: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var index: Int

    init(name: String, index: Int) {
        self.id = UUID()
        self.name = name
        self.index = index
    }
}

// MARK: - Row

struct Row: Identifiable, Codable, Equatable {
    let id: UUID
    var index: Int
    var values: [String: String]

    init(index: Int, values: [String: String]) {
        self.id = UUID()
        self.index = index
        self.values = values
    }
}

// MARK: - LLMParameters

struct LLMParameters: Codable, Equatable {
    var temperature: Double = 1.0
    var maxTokens: Int? = nil
    var topP: Double = 1.0
    var frequencyPenalty: Double = 0.0
    var presencePenalty: Double = 0.0
}

// MARK: - Prompt

struct Prompt: Identifiable, Codable, Equatable {
    let id: UUID
    var fileID: UUID
    var name: String
    var template: String
    var parameters: LLMParameters
    var createdAt: Date
    var updatedAt: Date

    init(fileID: UUID, name: String = "Prompt") {
        self.id = UUID()
        self.fileID = fileID
        self.name = name
        self.template = ""
        self.parameters = LLMParameters()
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - ParsedTable

struct ParsedTable: Codable, Equatable {
    var columns: [ColumnDef]
    var rows: [Row]

    static let empty = ParsedTable(columns: [], rows: [])
}
