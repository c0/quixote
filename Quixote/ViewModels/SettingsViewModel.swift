import Foundation
import SwiftUI

private let kKeychainOpenAIKey  = "openai-api-key"
private let kConcurrencyKey     = "quixote.concurrency"
private let kRateLimitKey       = "quixote.rateLimit"
private let kMaxRetriesKey          = "quixote.maxRetries"
private let kShowExtrapolationKey   = "quixote.showExtrapolation"
private let kExtrapolationScaleKey  = "quixote.extrapolationScale"
private let kShowCosineSimilarityKey = "quixote.showCosineSimilarity"
private let kShowRougeMetricsKey     = "quixote.showRougeMetrics"
// Legacy key written by CP-3 RunControlsView — migrated to Keychain on first launch
private let kLegacyAPIKey       = "quixote.openai.apiKey"

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

    @Published var availableModels: [ModelConfig] = ModelConfig.builtIn
    @Published var groupedModels: [(family: String, models: [ModelConfig])] = ModelConfig.grouped(ModelConfig.builtIn)

    init() {
        migrateLegacyKeyIfNeeded()
        openAIKey = KeychainHelper.read(for: kKeychainOpenAIKey) ?? ""
        observeKeyChanges()
        if !openAIKey.isEmpty {
            refreshModels()
        }
    }

    // MARK: - Key management

    func saveKey() {
        let trimmed = openAIKey.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            KeychainHelper.delete(for: kKeychainOpenAIKey)
        } else {
            KeychainHelper.save(trimmed, for: kKeychainOpenAIKey)
        }
        keyValidationResult = nil
        NotificationCenter.default.post(name: .quixoteAPIKeyDidChange, object: nil)
    }

    func validateKey() {
        let trimmed = openAIKey.trimmingCharacters(in: .whitespaces)
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
                    saveKey()
                    keyValidationResult = .valid
                    // Parse model list from the validation response
                    if let models = try? await OpenAIService.fetchModels(apiKey: trimmed) {
                        updateAvailableModels(models)
                    }
                } else if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                    keyValidationResult = .invalid("Invalid API key")
                } else {
                    keyValidationResult = .invalid("Unexpected response — key saved anyway")
                    saveKey()
                }
            } catch {
                keyValidationResult = .invalid("Network error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Model list

    func refreshModels() {
        let trimmed = openAIKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        Task {
            if let models = try? await OpenAIService.fetchModels(apiKey: trimmed) {
                updateAvailableModels(models)
            }
        }
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
                let newKey = KeychainHelper.read(for: kKeychainOpenAIKey) ?? ""
                self.openAIKey = newKey
                if !newKey.isEmpty {
                    self.refreshModels()
                }
            }
        }
    }

    // MARK: - Migration

    private func migrateLegacyKeyIfNeeded() {
        guard let legacy = UserDefaults.standard.string(forKey: kLegacyAPIKey),
              !legacy.isEmpty,
              KeychainHelper.read(for: kKeychainOpenAIKey) == nil else { return }
        KeychainHelper.save(legacy, for: kKeychainOpenAIKey)
        UserDefaults.standard.removeObject(forKey: kLegacyAPIKey)
    }
}
