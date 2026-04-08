import Foundation

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
        } catch is CancellationError {
            throw LLMServiceError.cancelled
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
}
