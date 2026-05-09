import Foundation
import Testing
@testable import Quixote

struct RequestBodyTests {
    @Test
    func standardModelRequestIncludesSamplingParameters() throws {
        var params = LLMParameters()
        params.temperature = 0.7
        params.topP = 0.8
        params.maxTokens = 250
        let model = ModelConfig(id: "gpt-4o-mini", displayName: "GPT-4o mini", provider: .openAI)

        let json = try OpenAIRequestBodyBuilder.jsonString(
            prompt: "Describe the row.",
            systemMessage: "Use a concise style.",
            model: model,
            params: params
        )
        let body = try decodeJSONObject(json)

        #expect(body["model"] as? String == "gpt-4o-mini")
        #expect(body["temperature"] as? Double == 0.7)
        #expect(body["top_p"] as? Double == 0.8)
        #expect(body["max_tokens"] as? Int == 250)
        #expect(json.contains("Authorization") == false)
        #expect(json.contains("Bearer") == false)
        #expect(json.contains("Content-Type") == false)
    }

    @Test
    func maxTokensIsOmittedWhenUnset() throws {
        let model = ModelConfig(id: "gpt-4o-mini", displayName: "GPT-4o mini", provider: .openAI)

        let json = try OpenAIRequestBodyBuilder.jsonString(
            prompt: "Describe the row.",
            systemMessage: "",
            model: model,
            params: LLMParameters()
        )
        let body = try decodeJSONObject(json)

        #expect(body["max_tokens"] == nil)
        #expect((body["messages"] as? [[String: Any]])?.count == 1)
    }

    @Test
    func reasoningModelUsesReasoningEffortAndOmitsTemperature() throws {
        var params = LLMParameters()
        params.temperature = 0.4
        params.reasoningEffort = .medium
        let model = ModelConfig(
            id: "gpt-5",
            displayName: "GPT-5",
            provider: .openAI,
            supportedReasoningLevels: [.low, .medium, .high]
        )

        let json = try OpenAIRequestBodyBuilder.jsonString(
            prompt: "Describe the row.",
            systemMessage: "Think carefully.",
            model: model,
            params: params
        )
        let body = try decodeJSONObject(json)

        #expect(body["reasoning_effort"] as? String == "medium")
        #expect(body["temperature"] == nil)
        #expect(body["top_p"] as? Double == 1.0)
    }

    @Test
    func cachedEntryDecodesOlderPayloadWithoutRequestBody() throws {
        let json = """
        {
          "responseText": "Done",
          "rawResponse": "{}",
          "tokenUsage": { "input": 1, "output": 2, "total": 3 },
          "durationMs": 42,
          "costUSD": 0.01,
          "cosineSimilarity": 0.5,
          "cachedAt": "2026-05-08T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let entry = try decoder.decode(CachedEntry.self, from: Data(json.utf8))

        #expect(entry.requestBodyJSON == nil)
        #expect(entry.responseText == "Done")
    }

    @MainActor
    @Test
    func hydrateCachedCompletedResultsLoadsStoredRequestBody() {
        let fileID = UUID()
        var prompt = Prompt(fileID: fileID, name: "Describe")
        prompt.template = "Describe {{name}}."
        prompt.systemMessage = "Use {{tone}} tone."
        let columns = [
            ColumnDef(name: "name", index: 0),
            ColumnDef(name: "tone", index: 1)
        ]
        let row = Row(index: 0, values: ["name": "Widget", "tone": "plain"])
        let model = ModelConfig(id: "gpt-4o-mini", displayName: "GPT-4o mini", provider: .openAI)
        let profile = ProviderProfile.defaults[0]
        let config = ResolvedFileModelConfig(
            id: UUID(),
            fileID: fileID,
            model: model,
            providerProfile: profile,
            parameters: LLMParameters(),
            displayName: model.displayName
        )
        let expandedPrompt = InterpolationEngine.expand(template: prompt.template, row: row, columns: columns)
        let expandedSystemMessage = InterpolationEngine.expandSystemMessage(prompt.systemMessage, row: row, columns: columns)
        let cacheKey = ResponseCache.cacheKey(
            expandedPrompt: expandedPrompt,
            systemMessage: expandedSystemMessage,
            modelID: config.modelID,
            providerProfileID: config.providerProfileID,
            providerBaseURL: config.providerProfile.normalizedBaseURL,
            params: config.parameters
        )
        let storedRequest = "{\n  \"model\" : \"cached-model\"\n}"
        ResponseCache.shared.store(
            entry: CachedEntry(
                responseText: "Cached response",
                rawResponse: "{}",
                requestBodyJSON: storedRequest,
                tokenUsage: TokenUsage(input: 1, output: 1, total: 2),
                durationMs: 10,
                costUSD: 0,
                cosineSimilarity: 0,
                cachedAt: Date()
            ),
            for: cacheKey
        )
        defer { ResponseCache.shared.removeEntries(for: [cacheKey]) }

        let processing = ProcessingViewModel()
        processing.hydrateCachedCompletedResults(
            prompts: [prompt],
            rows: [row],
            columns: columns,
            modelConfigs: [config]
        )

        #expect(processing.results.values.first?.requestBodyJSON == storedRequest)
    }

    private func decodeJSONObject(_ json: String) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try #require(object as? [String: Any])
    }
}
