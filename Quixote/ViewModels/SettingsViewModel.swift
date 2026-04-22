import SwiftUI

private let kConcurrencyKey     = "quixote.concurrency"
private let kRateLimitKey       = "quixote.rateLimit"
private let kMaxRetriesKey          = "quixote.maxRetries"
private let kShowExtrapolationKey   = "quixote.showExtrapolation"
private let kExtrapolationScaleKey  = "quixote.extrapolationScale"
private let kShowCosineSimilarityKey = "quixote.showCosineSimilarity"
private let kShowRougeMetricsKey     = "quixote.showRougeMetrics"
private let kHasSavedOpenAIKey = "quixote.hasSavedOpenAIKey"
private let kLegacyPlaintextAPIKey = "quixote.openai.apiKey"

extension Notification.Name {
    static let quixoteAPIKeyDidChange = Notification.Name("quixoteAPIKeyDidChange")
}

enum KeyValidationResult {
    case valid
    case invalid(String)
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var openAIKey: String = ""
    @Published var concurrency: Int = UserDefaults.standard.integer(forKey: kConcurrencyKey) == 0
        ? 2 : UserDefaults.standard.integer(forKey: kConcurrencyKey)
    @Published var rateLimit: Int = UserDefaults.standard.integer(forKey: kRateLimitKey) == 0
        ? 5 : UserDefaults.standard.integer(forKey: kRateLimitKey)
    @Published var maxRetries: Int = {
        if UserDefaults.standard.object(forKey: "quixote.maxRetries") == nil { return 3 }
        return UserDefaults.standard.integer(forKey: "quixote.maxRetries")
    }()

    @Published var showExtrapolation: Bool = {
        if UserDefaults.standard.object(forKey: "quixote.showExtrapolation") == nil { return true }
        return UserDefaults.standard.bool(forKey: "quixote.showExtrapolation")
    }()

    @Published var extrapolationScale: ExtrapolationScale = {
        guard let raw = UserDefaults.standard.string(forKey: "quixote.extrapolationScale"),
              let scale = ExtrapolationScale(rawValue: raw) else { return .oneK }
        return scale
    }()

    @Published var showCosineSimilarity: Bool = {
        if UserDefaults.standard.object(forKey: kShowCosineSimilarityKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: kShowCosineSimilarityKey)
    }()

    @Published var showRougeMetrics: Bool = {
        if UserDefaults.standard.object(forKey: kShowRougeMetricsKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: kShowRougeMetricsKey)
    }()

    @Published var isValidatingKey = false
    @Published var keyValidationResult: KeyValidationResult? = nil
    @Published var hasSavedAPIKey: Bool = UserDefaults.standard.bool(forKey: kHasSavedOpenAIKey)

    @Published var availableModels: [ModelConfig] = ModelConfig.builtIn
    @Published var groupedModels: [(family: String, models: [ModelConfig])] = ModelConfig.grouped(ModelConfig.builtIn)

    init() {
        UserDefaults.standard.removeObject(forKey: kLegacyPlaintextAPIKey)
        observeKeyChanges()
    }

    // MARK: - Key management

    @discardableResult
    func saveKey() -> Bool {
        let trimmed = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                if !hasSavedAPIKey {
                    try KeychainHelper.deleteOpenAIKey()
                    setHasSavedAPIKey(false)
                }
            } else {
                try KeychainHelper.saveOpenAIKey(trimmed)
                setHasSavedAPIKey(true)
                openAIKey = ""
            }
            keyValidationResult = nil
            NotificationCenter.default.post(name: .quixoteAPIKeyDidChange, object: nil)
            return true
        } catch {
            keyValidationResult = .invalid(error.localizedDescription)
            return false
        }
    }

    func validateKey() {
        let trimmed: String
        do {
            trimmed = try apiKeyForUserAction(preferUnsavedInput: true)
        } catch {
            keyValidationResult = .invalid(error.localizedDescription)
            return
        }

        guard !trimmed.isEmpty else {
            keyValidationResult = .invalid("Enter an API key first")
            return
        }
        isValidatingKey = true
        keyValidationResult = nil

        Task {
            defer { isValidatingKey = false }
            do {
                var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
                request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    if !openAIKey.trimmingCharacters(in: .whitespaces).isEmpty {
                        _ = saveKey()
                    }
                    keyValidationResult = .valid
                    // Parse model list from the validation response
                    if let models = try? await OpenAIService.fetchModels(apiKey: trimmed) {
                        updateAvailableModels(models)
                    }
                } else if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                    keyValidationResult = .invalid("Invalid API key")
                } else {
                    keyValidationResult = .invalid("Unexpected response — key saved anyway")
                    if !openAIKey.trimmingCharacters(in: .whitespaces).isEmpty {
                        _ = saveKey()
                    }
                }
            } catch {
                keyValidationResult = .invalid("Network error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Model list

    func refreshModels() {
        let trimmed: String
        do {
            trimmed = try apiKeyForUserAction(preferUnsavedInput: true)
        } catch {
            return
        }

        Task {
            if let models = try? await OpenAIService.fetchModels(apiKey: trimmed) {
                updateAvailableModels(models)
            }
        }
    }

    func markKeyFieldEdited() {
        keyValidationResult = nil
    }

    private func updateAvailableModels(_ models: [ModelConfig]) {
        let eligibleModels = ModelConfig.eligibleTextModels(models)
        availableModels = eligibleModels.isEmpty ? ModelConfig.builtIn : eligibleModels
        groupedModels = ModelConfig.grouped(availableModels)
    }

    // MARK: - Processing params

    func saveConcurrency(_ value: Int) {
        concurrency = value
        UserDefaults.standard.set(value, forKey: kConcurrencyKey)
    }

    func saveRateLimit(_ value: Int) {
        rateLimit = value
        UserDefaults.standard.set(value, forKey: kRateLimitKey)
    }

    func saveMaxRetries(_ value: Int) {
        maxRetries = value
        UserDefaults.standard.set(value, forKey: kMaxRetriesKey)
    }

    func saveShowExtrapolation(_ value: Bool) {
        showExtrapolation = value
        UserDefaults.standard.set(value, forKey: kShowExtrapolationKey)
    }

    func saveExtrapolationScale(_ value: ExtrapolationScale) {
        extrapolationScale = value
        UserDefaults.standard.set(value.rawValue, forKey: kExtrapolationScaleKey)
    }

    func saveShowCosineSimilarity(_ value: Bool) {
        showCosineSimilarity = value
        UserDefaults.standard.set(value, forKey: kShowCosineSimilarityKey)
    }

    func saveShowRougeMetrics(_ value: Bool) {
        showRougeMetrics = value
        UserDefaults.standard.set(value, forKey: kShowRougeMetricsKey)
    }

    // MARK: - Cache

    func clearCache() {
        ResponseCache.shared.clearAll()
    }

    // MARK: - Key change sync

    private func observeKeyChanges() {
        NotificationCenter.default.addObserver(
            forName: .quixoteAPIKeyDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.hasSavedAPIKey = UserDefaults.standard.bool(forKey: kHasSavedOpenAIKey)
            }
        }
    }

    func apiKeyForUserAction(preferUnsavedInput: Bool = false) throws -> String {
        let typed = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if preferUnsavedInput, !typed.isEmpty {
            return typed
        }
        return try KeychainHelper.readOpenAIKey()
    }

    private func setHasSavedAPIKey(_ hasSaved: Bool) {
        hasSavedAPIKey = hasSaved
        UserDefaults.standard.set(hasSaved, forKey: kHasSavedOpenAIKey)
    }
}
