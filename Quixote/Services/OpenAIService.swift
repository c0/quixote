import Foundation

// MARK: - /v1/models response types

private struct OpenAIModelListResponse: Codable {
    let data: [OpenAIModelEntry]
}

private struct OpenAIModelEntry: Codable {
    let id: String
    let created: Int
    let ownedBy: String

    enum CodingKeys: String, CodingKey {
        case id, created
        case ownedBy = "owned_by"
    }
}

// MARK: - OpenAIService

struct OpenAIService: LLMService {
    let apiKey: String
    private let session = URLSession.shared

    func complete(
        prompt: String,
        model: ModelConfig,
        params: LLMParameters
    ) async throws -> LLMResponse {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": model.id,
            "messages": [["role": "user", "content": prompt]],
            "temperature": params.temperature,
            "top_p": params.topP,
            "frequency_penalty": params.frequencyPenalty,
            "presence_penalty": params.presencePenalty,
        ]
        if let max = params.maxTokens {
            body["max_tokens"] = max
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let start = Date()
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw error
        }

        let durationMs = Int(Date().timeIntervalSince(start) * 1000)

        guard let http = response as? HTTPURLResponse else {
            throw LLMServiceError.decodingFailed("no HTTP response")
        }

        switch http.statusCode {
        case 200:
            break
        case 401:
            throw LLMServiceError.invalidAPIKey
        case 429:
            throw LLMServiceError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMServiceError.serverError(http.statusCode, body)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw LLMServiceError.decodingFailed(preview)
        }

        let usage: TokenUsage
        if let u = json["usage"] as? [String: Any] {
            usage = TokenUsage(
                input: u["prompt_tokens"] as? Int ?? 0,
                output: u["completion_tokens"] as? Int ?? 0,
                total: u["total_tokens"] as? Int ?? 0
            )
        } else {
            usage = TokenUsage(input: 0, output: 0, total: 0)
        }

        return LLMResponse(text: content, tokenUsage: usage, durationMs: durationMs)
    }

    // MARK: - Fetch available models

    static func fetchModels(apiKey: String) async throws -> [ModelConfig] {
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LLMServiceError.decodingFailed("no HTTP response")
        }
        switch http.statusCode {
        case 401: throw LLMServiceError.invalidAPIKey
        case 429: throw LLMServiceError.rateLimited
        case 200: break
        default:
            let body = String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw LLMServiceError.serverError(http.statusCode, body)
        }

        let list = try JSONDecoder().decode(OpenAIModelListResponse.self, from: data)

        return list.data
            .filter { Self.isChatModel($0.id) }
            .map { entry in
                ModelConfig(
                    id: entry.id,
                    displayName: Self.displayName(for: entry.id),
                    provider: .openAI,
                    created: entry.created
                )
            }
            .sorted { $0.created ?? 0 > $1.created ?? 0 }
    }

    // MARK: - Model filtering & display

    /// Filter to chat-capable models (GPT family, o-series reasoning models)
    private static func isChatModel(_ id: String) -> Bool {
        let chatPrefixes = ["gpt-4", "gpt-3.5", "chatgpt", "o1", "o3", "o4"]
        return chatPrefixes.contains { id.hasPrefix($0) }
            && !id.contains("instruct")
            && !id.contains("base")
    }

    /// Convert API model ID to human-readable display name
    private static func displayName(for id: String) -> String {
        // Extract date suffix if present: "gpt-4o-2024-05-13" → base "gpt-4o", date "2024-05-13"
        var base = id
        var dateSuffix: String?
        if let range = id.range(of: #"\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) {
            dateSuffix = String(id[range])
            base = String(id[id.startIndex..<range.lowerBound])
            // Remove trailing hyphen from base
            if base.hasSuffix("-") { base = String(base.dropLast()) }
        }

        let baseName: String
        switch base {
        case "gpt-4o":       baseName = "GPT-4o"
        case "gpt-4o-mini":  baseName = "GPT-4o mini"
        case "gpt-4-turbo":  baseName = "GPT-4 Turbo"
        case "gpt-4":        baseName = "GPT-4"
        case "gpt-3.5-turbo":baseName = "GPT-3.5 Turbo"
        case "o1":           baseName = "o1"
        case "o1-mini":      baseName = "o1 mini"
        case "o1-pro":       baseName = "o1 pro"
        case "o3":           baseName = "o3"
        case "o3-mini":      baseName = "o3 mini"
        case "o4-mini":      baseName = "o4 mini"
        default:
            // Fallback: title-case the base, replace hyphens with spaces
            baseName = base.replacingOccurrences(of: "-", with: " ").capitalized
        }

        if let dateSuffix {
            return "\(baseName) (\(dateSuffix))"
        }
        return baseName
    }
}
