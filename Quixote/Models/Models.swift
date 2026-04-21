import CryptoKit
import Foundation

// MARK: - FileType

enum FileType: String, Codable, CaseIterable {
    case csv
    case json
    case xlsx
    case unknown

    static func detect(from url: URL) -> FileType {
        switch url.pathExtension.lowercased() {
        case "csv", "tsv", "tab": return .csv
        case "json": return .json
        case "xlsx": return .xlsx
        default: return .unknown
        }
    }
}

enum FileRestoreState: String, Codable, Equatable {
    case available
    case bookmarkMissing
    case bookmarkResolutionFailed
    case accessDenied
    case missing
    case parseFailed

    var isAvailable: Bool {
        self == .available
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
    var restoreState: FileRestoreState

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.displayName = url.deletingPathExtension().lastPathComponent
        self.fileType = FileType.detect(from: url)
        self.addedAt = Date()
        self.contentHash = ""
        self.restoreState = .available
    }

    var isAvailable: Bool {
        restoreState.isAvailable
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
        self.id = Self.stableID(index: index, values: values)
        self.index = index
        self.values = values
    }

    private static func stableID(index: Int, values: [String: String]) -> UUID {
        struct StableRowPayload: Encodable {
            let version: Int
            let index: Int
            let values: [StringPair]
        }

        struct StringPair: Encodable {
            let key: String
            let value: String
        }

        let payload = StableRowPayload(
            version: 1,
            index: index,
            values: values
                .map { StringPair(key: $0.key, value: $0.value) }
                .sorted { lhs, rhs in
                    if lhs.key != rhs.key { return lhs.key < rhs.key }
                    return lhs.value < rhs.value
                }
        )

        let data = (try? JSONEncoder().encode(payload)) ?? "\(index)|\(values)".data(using: .utf8) ?? Data()
        var bytes = Array(SHA256.hash(data: data).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

// MARK: - LLMParameters

/// Reasoning effort level for o-series and GPT-5 models
enum ReasoningEffort: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        rawValue.capitalized
    }
}

struct LLMParameters: Codable, Equatable {
    var temperature: Double = 1.0
    var maxTokens: Int? = nil
    var topP: Double = 1.0
    // Deprecated runtime settings. Kept for backward-compatible decoding.
    var frequencyPenalty: Double = 0.0
    var presencePenalty: Double = 0.0
    var reasoningEffort: ReasoningEffort? = nil
}

// MARK: - Prompt

struct Prompt: Identifiable, Codable, Equatable {
    let id: UUID
    var fileID: UUID
    var name: String
    var systemMessage: String
    var template: String
    var parameters: LLMParameters
    var createdAt: Date
    var updatedAt: Date

    init(fileID: UUID, name: String = "Prompt") {
        self.id = UUID()
        self.fileID = fileID
        self.name = name
        self.systemMessage = ""
        self.template = ""
        self.parameters = LLMParameters()
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case fileID
        case name
        case systemMessage
        case template
        case parameters
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fileID = try container.decode(UUID.self, forKey: .fileID)
        name = try container.decode(String.self, forKey: .name)
        systemMessage = try container.decodeIfPresent(String.self, forKey: .systemMessage) ?? ""
        template = try container.decode(String.self, forKey: .template)
        parameters = try container.decodeIfPresent(LLMParameters.self, forKey: .parameters) ?? LLMParameters()
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// MARK: - ModelConfig

struct ModelConfig: Identifiable, Codable, Equatable, Hashable {
    var id: String        // e.g. "gpt-4o-mini"
    var displayName: String
    var provider: LLMProvider
    var created: Int?     // Unix timestamp from API; nil for builtIn
    var supportedReasoningLevels: [ReasoningEffort] = []

    static let builtIn: [ModelConfig] = sortedForSelection([
        ModelConfig(id: "gpt-5.4",      displayName: "GPT-5.4",       provider: .openAI, supportedReasoningLevels: [.low, .medium, .high]),
        ModelConfig(id: "gpt-5",        displayName: "GPT-5",         provider: .openAI, supportedReasoningLevels: [.low, .medium, .high]),
        ModelConfig(id: "gpt-5-mini",   displayName: "GPT-5 mini",    provider: .openAI, supportedReasoningLevels: [.low, .medium, .high]),
        ModelConfig(id: "gpt-4o",       displayName: "GPT-4o",        provider: .openAI, supportedReasoningLevels: []),
        ModelConfig(id: "gpt-4o-mini",  displayName: "GPT-4o mini",   provider: .openAI, supportedReasoningLevels: []),
        ModelConfig(id: "gpt-4-turbo",  displayName: "GPT-4 Turbo",   provider: .openAI, supportedReasoningLevels: []),
        ModelConfig(id: "gpt-3.5-turbo",displayName: "GPT-3.5 Turbo", provider: .openAI, supportedReasoningLevels: []),
    ])

    // MARK: - Family grouping

    /// Whether this model supports the reasoning_effort parameter
    var supportsReasoningEffort: Bool {
        !supportedReasoningLevels.isEmpty
    }

    // MARK: - Pricing (USD per 1M tokens)

    /// Input cost per 1M tokens in USD
    var costPerMillionInput: Double {
        Self.pricing[id]?.input ?? 0
    }

    /// Output cost per 1M tokens in USD
    var costPerMillionOutput: Double {
        Self.pricing[id]?.output ?? 0
    }

    private struct ModelPricing {
        let input: Double   // per 1M tokens
        let output: Double  // per 1M tokens
    }

    /// Known per-model pricing (USD per 1M tokens). Falls back to 0 for unknown models.
    private static let pricing: [String: ModelPricing] = [
        "gpt-4o":        ModelPricing(input: 2.50,  output: 10.00),
        "gpt-4o-mini":   ModelPricing(input: 0.15,  output: 0.60),
        "gpt-4-turbo":   ModelPricing(input: 10.00, output: 30.00),
        "gpt-4":         ModelPricing(input: 30.00, output: 60.00),
        "gpt-3.5-turbo": ModelPricing(input: 0.50,  output: 1.50),
        "gpt-5":         ModelPricing(input: 10.00, output: 30.00),
        "gpt-5.4":       ModelPricing(input: 5.00,  output: 15.00),
        "gpt-5-mini":    ModelPricing(input: 1.50,  output: 6.00),
        "o1":            ModelPricing(input: 15.00, output: 60.00),
        "o1-mini":       ModelPricing(input: 3.00,  output: 12.00),
        "o1-pro":        ModelPricing(input: 150.00, output: 600.00),
        "o3":            ModelPricing(input: 10.00, output: 40.00),
        "o3-mini":       ModelPricing(input: 1.10,  output: 4.40),
        "o4-mini":       ModelPricing(input: 1.10,  output: 4.40),
    ]

    /// Compute cost in USD for the given token usage
    func costFor(inputTokens: Int, outputTokens: Int) -> Double {
        let inputCost = Double(inputTokens) / 1_000_000 * costPerMillionInput
        let outputCost = Double(outputTokens) / 1_000_000 * costPerMillionOutput
        return inputCost + outputCost
    }

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

    /// Whether this model should appear in text/chat model selection.
    static func isEligibleTextModelID(_ id: String) -> Bool {
        let lower = id.lowercased()
        guard lower.hasPrefix("gpt-") || lower.hasPrefix("chatgpt") else { return false }
        guard !lower.hasPrefix("o") else { return false }

        let excludedFragments = [
            "audio",
            "dall",
            "image",
            "img",
            "realtime",
            "speech",
            "tts",
            "transcrib",
            "voice",
            "whisper"
        ]
        guard !excludedFragments.contains(where: { lower.contains($0) }) else { return false }

        return !lower.contains("instruct") && !lower.contains("base")
    }

    static func eligibleTextModels(_ models: [ModelConfig]) -> [ModelConfig] {
        sortedForSelection(models.filter { isEligibleTextModelID($0.id) })
    }

    static func sortedForSelection(_ models: [ModelConfig]) -> [ModelConfig] {
        models.sorted { lhs, rhs in
            let lhsRank = versionRank(for: lhs.family)
            let rhsRank = versionRank(for: rhs.family)
            if lhsRank != rhsRank { return lhsRank.lexicographicallyPrecedes(rhsRank) == false }

            let lhsCreated = lhs.created ?? 0
            let rhsCreated = rhs.created ?? 0
            if lhsCreated != rhsCreated { return lhsCreated > rhsCreated }

            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    /// Group models by family, newest/highest model versions first.
    static func grouped(_ models: [ModelConfig]) -> [(family: String, models: [ModelConfig])] {
        let groups = Dictionary(grouping: eligibleTextModels(models), by: { $0.family })
        return groups
            .map { (family: $0.key, models: sortedForSelection($0.value)) }
            .sorted { lhs, rhs in
                let lhsRank = versionRank(for: lhs.family)
                let rhsRank = versionRank(for: rhs.family)
                if lhsRank != rhsRank { return lhsRank.lexicographicallyPrecedes(rhsRank) == false }
                return lhs.family.localizedStandardCompare(rhs.family) == .orderedAscending
            }
    }

    static func supportedReasoningLevels(for id: String) -> [ReasoningEffort] {
        let prefixes = ["o1", "o3", "o4", "gpt-5"]
        guard prefixes.contains(where: { id.hasPrefix($0) }) else { return [] }
        return [.low, .medium, .high]
    }

    private static func versionRank(for id: String) -> [Int] {
        let lower = id.lowercased()
        guard let range = lower.range(of: #"(?:gpt|chatgpt)-(\d+(?:\.\d+)*)"#, options: .regularExpression) else {
            return [0]
        }

        let matched = String(lower[range])
        guard let versionRange = matched.range(of: #"\d+(?:\.\d+)*"#, options: .regularExpression) else {
            return [0]
        }

        return matched[versionRange]
            .split(separator: ".")
            .map { Int($0) ?? 0 }
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
    case pending, inProgress, completed, failed, cancelled
}

// MARK: - TokenUsage

struct TokenUsage: Codable, Equatable {
    var input: Int
    var output: Int
    var total: Int
}

// MARK: - ExtrapolationScale

enum ExtrapolationScale: String, Codable, CaseIterable {
    case oneK = "1K"
    case oneMillion = "1M"
    case tenMillion = "10M"

    var multiplier: Int {
        switch self {
        case .oneK:         return 1_000
        case .oneMillion:   return 1_000_000
        case .tenMillion:   return 10_000_000
        }
    }

    var displayName: String { rawValue }
}

// MARK: - ProcessingRun

struct ProcessingRun: Identifiable, Codable {
    let id: UUID
    var promptID: UUID
    var modelID: String
    var modelConfigID: UUID?
    var status: RunStatus
    var startedAt: Date
    var completedAt: Date?

    init(promptID: UUID, modelID: String, modelConfigID: UUID? = nil) {
        self.id = UUID()
        self.promptID = promptID
        self.modelID = modelID
        self.modelConfigID = modelConfigID
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
    var modelConfigID: UUID?
    var responseText: String?
    var status: ResultStatus
    var tokenUsage: TokenUsage?
    var costUSD: Double?
    var durationMs: Int?
    var retryCount: Int = 0
    var finishedAt: Date?
    var cosineSimilarity: Double?
    var rouge1: Double?
    var rouge2: Double?
    var rougeL: Double?

    init(runID: UUID, rowID: UUID, promptID: UUID, modelID: String, modelConfigID: UUID? = nil) {
        self.id = UUID()
        self.runID = runID
        self.rowID = rowID
        self.promptID = promptID
        self.modelID = modelID
        self.modelConfigID = modelConfigID
        self.status = .pending
    }
}

// MARK: - FileModelConfig

struct FileModelConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var fileID: UUID
    var modelID: String
    var parameters: LLMParameters

    init(id: UUID = UUID(), fileID: UUID, modelID: String, parameters: LLMParameters = LLMParameters()) {
        self.id = id
        self.fileID = fileID
        self.modelID = modelID
        self.parameters = parameters
    }
}

struct ResolvedFileModelConfig: Identifiable, Codable, Equatable {
    let id: UUID
    let fileID: UUID
    let model: ModelConfig
    let parameters: LLMParameters
    let displayName: String

    var modelID: String { model.id }
}

// MARK: - ParsedTable

struct ParsedTable: Codable, Equatable {
    var columns: [ColumnDef]
    var rows: [Row]

    static let empty = ParsedTable(columns: [], rows: [])
}
