import Foundation

struct LLMResponse {
    var text: String
    var tokenUsage: TokenUsage
    var durationMs: Int
}

enum LLMServiceError: LocalizedError {
    case invalidAPIKey
    case rateLimited
    case serverError(Int, String)
    case decodingFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:          return "Invalid API key"
        case .rateLimited:            return "Rate limited — too many requests"
        case .serverError(let c, let m): return "Server error \(c): \(m)"
        case .decodingFailed(let d):  return "Unexpected response: \(d)"
        case .cancelled:              return "Cancelled"
        }
    }
}

protocol LLMService {
    func complete(
        prompt: String,
        model: ModelConfig,
        params: LLMParameters
    ) async throws -> LLMResponse
}
