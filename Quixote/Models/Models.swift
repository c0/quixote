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

// MARK: - ModelConfig

struct ModelConfig: Identifiable, Codable, Equatable, Hashable {
    var id: String        // e.g. "gpt-4o-mini"
    var displayName: String
    var provider: LLMProvider
    var created: Int?     // Unix timestamp from API; nil for builtIn

    static let builtIn: [ModelConfig] = [
        ModelConfig(id: "gpt-4o",       displayName: "GPT-4o",        provider: .openAI),
        ModelConfig(id: "gpt-4o-mini",  displayName: "GPT-4o mini",   provider: .openAI),
        ModelConfig(id: "gpt-4-turbo",  displayName: "GPT-4 Turbo",   provider: .openAI),
        ModelConfig(id: "gpt-3.5-turbo",displayName: "GPT-3.5 Turbo", provider: .openAI),
    ]

    // MARK: - Family grouping

    /// Extract the model family from the ID (e.g. "gpt-4o" from "gpt-4o-2024-05-13")
    var family: String {
        var base = id
        // Strip date suffixes like "-2024-05-13", "-0125", "-1106"
        if let range = base.range(of: #"-?\d{4}(-\d{2}-\d{2})?$"#, options: .regularExpression) {
            base = String(base[base.startIndex..<range.lowerBound])
        }
        // Strip qualifiers
        let qualifiers = ["-mini", "-turbo", "-preview"]
        for q in qualifiers {
            if base.hasSuffix(q) {
                base = String(base.dropLast(q.count))
            }
        }
        return base
    }

    /// Group models by family, sort families alphabetically, within each family sort by created desc
    static func grouped(_ models: [ModelConfig]) -> [(family: String, models: [ModelConfig])] {
        let groups = Dictionary(grouping: models, by: { $0.family })
        return groups
            .map { (family: $0.key, models: $0.value.sorted { ($0.created ?? 0) > ($1.created ?? 0) }) }
            .sorted { $0.family.localizedStandardCompare($1.family) == .orderedAscending }
    }
}

enum LLMProvider: String, Codable {
    case openAI
}

// MARK: - RunStatus / ResultStatus

enum RunStatus: String, Codable {
    case pending, running, completed, cancelled, failed
}

enum ResultStatus: String, Codable {
    case pending, inProgress, completed, failed
}

// MARK: - TokenUsage

struct TokenUsage: Codable, Equatable {
    var input: Int
    var output: Int
    var total: Int
}

// MARK: - ProcessingRun

struct ProcessingRun: Identifiable, Codable {
    let id: UUID
    var promptID: UUID
    var modelID: String
    var status: RunStatus
    var startedAt: Date
    var completedAt: Date?

    init(promptID: UUID, modelID: String) {
        self.id = UUID()
        self.promptID = promptID
        self.modelID = modelID
        self.status = .pending
        self.startedAt = Date()
    }
}

// MARK: - PromptResult

struct PromptResult: Identifiable, Codable, Equatable {
    let id: UUID
    var runID: UUID
    var rowID: UUID
    var promptID: UUID
    var modelID: String
    var responseText: String?
    var status: ResultStatus
    var tokenUsage: TokenUsage?
    var costUSD: Double?
    var durationMs: Int?

    init(runID: UUID, rowID: UUID, promptID: UUID, modelID: String) {
        self.id = UUID()
        self.runID = runID
        self.rowID = rowID
        self.promptID = promptID
        self.modelID = modelID
        self.status = .pending
    }
}

// MARK: - ParsedTable

struct ParsedTable: Codable, Equatable {
    var columns: [ColumnDef]
    var rows: [Row]

    static let empty = ParsedTable(columns: [], rows: [])
}
