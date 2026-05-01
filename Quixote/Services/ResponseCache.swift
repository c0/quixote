import Foundation
import CryptoKit

// MARK: - CachedEntry

struct CachedEntry: Codable {
    var responseText: String
    var tokenUsage: TokenUsage
    var durationMs: Int
    var costUSD: Double
    var cosineSimilarity: Double
    var rouge1: Double?
    var rouge2: Double?
    var rougeL: Double?
    var cachedAt: Date

    // Backward-compatible decode: old entries have no analytics fields
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        responseText = try c.decode(String.self, forKey: .responseText)
        tokenUsage = try c.decode(TokenUsage.self, forKey: .tokenUsage)
        durationMs = try c.decode(Int.self, forKey: .durationMs)
        costUSD = try c.decode(Double.self, forKey: .costUSD)
        cosineSimilarity = try c.decodeIfPresent(Double.self, forKey: .cosineSimilarity) ?? 0.0
        rouge1 = try c.decodeIfPresent(Double.self, forKey: .rouge1)
        rouge2 = try c.decodeIfPresent(Double.self, forKey: .rouge2)
        rougeL = try c.decodeIfPresent(Double.self, forKey: .rougeL)
        cachedAt = try c.decode(Date.self, forKey: .cachedAt)
    }

    init(responseText: String, tokenUsage: TokenUsage, durationMs: Int,
         costUSD: Double, cosineSimilarity: Double,
         rouge1: Double? = nil, rouge2: Double? = nil, rougeL: Double? = nil,
         cachedAt: Date) {
        self.responseText = responseText
        self.tokenUsage = tokenUsage
        self.durationMs = durationMs
        self.costUSD = costUSD
        self.cosineSimilarity = cosineSimilarity
        self.rouge1 = rouge1
        self.rouge2 = rouge2
        self.rougeL = rougeL
        self.cachedAt = cachedAt
    }
}

// MARK: - ResponseCache

@MainActor
final class ResponseCache: ObservableObject {

    static let shared = ResponseCache()

    @Published private(set) var entryCount: Int = 0

    private var store: [String: CachedEntry] = [:]

    private static let persistenceURL: URL = {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Quixote")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("response-cache.json")
    }()

    private init() { load() }

    // MARK: - Key generation

    static func cacheKey(
        expandedPrompt: String,
        systemMessage: String,
        modelID: String,
        params: LLMParameters
    ) -> String {
        let paramsString = [
            "\(params.temperature)",
            "\(params.maxTokens ?? -1)",
            "\(params.topP)",
            params.reasoningEffort?.rawValue ?? "none"
        ].joined(separator: "|")
        let raw = systemMessage + "\0" + expandedPrompt + "\0" + modelID + "\0" + paramsString
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Lookup / store

    func entry(for key: String) -> CachedEntry? {
        store[key]
    }

    func store(entry: CachedEntry, for key: String) {
        store[key] = entry
        entryCount = store.count
        scheduleSave()
    }

    // MARK: - Clear

    func clearAll() {
        store.removeAll()
        entryCount = 0
        try? FileManager.default.removeItem(at: Self.persistenceURL)
    }

    func removeEntries(for keys: Set<String>) {
        guard !keys.isEmpty else { return }
        saveTask?.cancel()
        for key in keys {
            store.removeValue(forKey: key)
        }
        entryCount = store.count
        persist()
    }

    // MARK: - Persistence

    private var saveTask: Task<Void, Never>?

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: Self.persistenceURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.persistenceURL),
              let decoded = try? JSONDecoder().decode([String: CachedEntry].self, from: data)
        else { return }
        store = decoded
        entryCount = store.count
    }
}
