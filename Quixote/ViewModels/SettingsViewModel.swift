import Foundation
import SwiftUI

private let kKeychainOpenAIKey  = "openai-api-key"
private let kConcurrencyKey     = "quixote.concurrency"
private let kRateLimitKey       = "quixote.rateLimit"
// Legacy key written by CP-3 RunControlsView — migrated to Keychain on first launch
private let kLegacyAPIKey       = "quixote.openai.apiKey"

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

    @Published var isValidatingKey = false
    @Published var keyValidationResult: KeyValidationResult? = nil

    init() {
        migrateLegacyKeyIfNeeded()
        openAIKey = KeychainHelper.read(for: kKeychainOpenAIKey) ?? ""
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

    // MARK: - Processing params

    func saveConcurrency(_ value: Int) {
        concurrency = value
        UserDefaults.standard.set(value, forKey: kConcurrencyKey)
    }

    func saveRateLimit(_ value: Int) {
        rateLimit = value
        UserDefaults.standard.set(value, forKey: kRateLimitKey)
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
