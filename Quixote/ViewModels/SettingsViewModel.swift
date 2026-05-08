import SwiftUI

private let kConcurrencyKey = "quixote.concurrency"
private let kRateLimitKey = "quixote.rateLimit"
private let kMaxRetriesKey = "quixote.maxRetries"
private let kShowExtrapolationKey = "quixote.showExtrapolation"
private let kExtrapolationScaleKey = "quixote.extrapolationScale"
private let kShowCosineSimilarityKey = "quixote.showCosineSimilarity"
private let kShowRougeMetricsKey = "quixote.showRougeMetrics"
private let kLegacyPlaintextAPIKey = "quixote.openai.apiKey"
private let kProviderProfilesKey = "quixote.providerProfiles"

extension Notification.Name {
    static let quixoteAPIKeyDidChange = Notification.Name("quixoteAPIKeyDidChange")
}

enum APIKeyUIState: Equatable {
    case blank
    case focused
    case typing
    case masked
    case reveal
    case validating
    case valid(modelCount: Int?)
    case saved
    case invalid(String)
    case revoked(String)
}

struct APIKeyStatusLine: Equatable {
    enum Kind: Equatable {
        case success
        case failure
        case warning
        case neutral
    }

    let text: String
    let kind: Kind
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var concurrency: Int = UserDefaults.standard.integer(forKey: kConcurrencyKey) == 0
        ? 10 : UserDefaults.standard.integer(forKey: kConcurrencyKey)
    @Published var rateLimit: Int = UserDefaults.standard.integer(forKey: kRateLimitKey) == 0
        ? 10 : UserDefaults.standard.integer(forKey: kRateLimitKey)
    @Published var maxRetries: Int = {
        if UserDefaults.standard.object(forKey: kMaxRetriesKey) == nil { return 3 }
        return UserDefaults.standard.integer(forKey: kMaxRetriesKey)
    }()

    @Published var showExtrapolation: Bool = {
        if UserDefaults.standard.object(forKey: kShowExtrapolationKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: kShowExtrapolationKey)
    }()

    @Published var extrapolationScale: ExtrapolationScale = {
        guard let raw = UserDefaults.standard.string(forKey: kExtrapolationScaleKey),
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

    @Published var availableModels: [ModelConfig] = ModelConfig.builtIn
    @Published var groupedModels: [(family: String, models: [ModelConfig])] = ModelConfig.grouped(ModelConfig.builtIn)
    @Published var providerProfiles: [ProviderProfile] = []
    @Published var providerAPIKeyDrafts: [String: String] = [:]
    @Published var providerStatusLines: [String: APIKeyStatusLine] = [:]
    @Published var refreshingProviderIDs: Set<String> = []
    @Published var visibleProviderAPIKeyIDs: Set<String> = []
    @Published private(set) var providerHasSavedAPIKeyIDs: Set<String> = []

    private var revealedProviderAPIKeys: [String: String] = [:]

    init() {
        UserDefaults.standard.removeObject(forKey: kLegacyPlaintextAPIKey)
        providerProfiles = loadProviderProfiles()
        refreshProviderSavedAPIKeyState()
        recomputeAvailableModels()
        observeKeyChanges()
    }

    func refreshModels() {
        refreshModels(for: ProviderProfile.openAIDefaultID)
    }

    func refreshModels(for profileID: String) {
        guard let profile = providerProfiles.first(where: { $0.id == profileID }) else { return }
        if let message = profile.baseURLValidationMessage {
            providerStatusLines[profileID] = APIKeyStatusLine(text: message, kind: .failure)
            return
        }
        let key = providerAPIKeyCandidate(for: profile)
        if profile.requiresAPIKey && key == nil {
            providerStatusLines[profileID] = APIKeyStatusLine(text: "Save an API key first", kind: .failure)
            return
        }
        refreshingProviderIDs.insert(profileID)
        providerStatusLines[profileID] = APIKeyStatusLine(text: "Refreshing models...", kind: .neutral)
        Task {
            defer {
                self.refreshingProviderIDs.remove(profileID)
            }
            do {
                let models = try await OpenAICompatibleService.fetchModels(profile: profile, apiKey: key)
                let ids = models.map(\.id)
                if let index = self.providerProfiles.firstIndex(where: { $0.id == profileID }) {
                    self.providerProfiles[index].discoveredModels = ids
                    self.persistProviderProfiles()
                }
                self.recomputeAvailableModels()
                self.providerStatusLines[profileID] = APIKeyStatusLine(text: "\(ids.count) models available", kind: .success)
            } catch {
                self.providerStatusLines[profileID] = APIKeyStatusLine(text: error.localizedDescription, kind: .warning)
            }
        }
    }

    func saveProvider(_ profile: ProviderProfile) {
        guard let index = providerProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
        providerProfiles[index] = profile.sanitized(fallback: ProviderProfile.defaults.first(where: { $0.id == profile.id }))
        if !profile.requiresAPIKey {
            visibleProviderAPIKeyIDs.remove(profile.id)
            revealedProviderAPIKeys[profile.id] = nil
        }
        persistProviderProfiles()
        refreshProviderSavedAPIKeyState()
        recomputeAvailableModels()
    }

    func saveProviderAPIKey(profileID: String) {
        guard let profile = providerProfiles.first(where: { $0.id == profileID }) else { return }
        let value = providerAPIKeyDrafts[profileID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else {
            providerStatusLines[profileID] = APIKeyStatusLine(text: "Enter an API key first", kind: .failure)
            return
        }
        do {
            try KeychainHelper.saveAPIKey(value, account: profile.keychainAccount)
            providerAPIKeyDrafts[profileID] = ""
            visibleProviderAPIKeyIDs.remove(profileID)
            revealedProviderAPIKeys[profileID] = nil
            providerHasSavedAPIKeyIDs.insert(profileID)
            providerStatusLines[profileID] = APIKeyStatusLine(text: "Saved to Keychain", kind: .success)
            NotificationCenter.default.post(name: .quixoteAPIKeyDidChange, object: nil)
        } catch {
            providerStatusLines[profileID] = APIKeyStatusLine(text: error.localizedDescription, kind: .failure)
        }
    }

    func testProvider(profileID: String) {
        refreshModels(for: profileID)
    }

    func providerAPIKeyState(for profile: ProviderProfile, isFocused: Bool) -> APIKeyUIState {
        if refreshingProviderIDs.contains(profile.id) {
            return .validating
        }

        if let status = providerStatusLines[profile.id] {
            switch status.kind {
            case .success:
                if status.text.localizedCaseInsensitiveContains("saved") {
                    return .saved
                }
                return .valid(modelCount: modelCount(from: status.text))
            case .failure:
                return .invalid(status.text)
            case .warning:
                return .revoked(status.text)
            case .neutral:
                break
            }
        }

        let draft = providerAPIKeyDrafts[profile.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !draft.isEmpty {
            if visibleProviderAPIKeyIDs.contains(profile.id) {
                return .reveal
            }
            return isFocused ? .typing : .masked
        }

        if providerHasSavedAPIKeyIDs.contains(profile.id) {
            return visibleProviderAPIKeyIDs.contains(profile.id) ? .reveal : .masked
        }

        return isFocused ? .focused : .blank
    }

    func providerAPIKeyDisplayText(for profile: ProviderProfile) -> String {
        let state = providerAPIKeyState(for: profile, isFocused: false)
        switch state {
        case .blank, .focused:
            return ""
        case .typing:
            return providerAPIKeyDrafts[profile.id] ?? ""
        case .masked, .validating, .valid, .saved, .invalid, .revoked:
            return String(repeating: "•", count: 20)
        case .reveal:
            let draft = providerAPIKeyDrafts[profile.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !draft.isEmpty { return providerAPIKeyDrafts[profile.id] ?? "" }
            return revealedProviderAPIKeys[profile.id] ?? ""
        }
    }

    func providerAPIKeyStatusLine(for profile: ProviderProfile) -> APIKeyStatusLine? {
        switch providerAPIKeyState(for: profile, isFocused: false) {
        case .validating:
            return APIKeyStatusLine(text: "Validating key...", kind: .neutral)
        case .valid(let modelCount):
            if let modelCount {
                return APIKeyStatusLine(text: "\(modelCount) models available · validated just now", kind: .success)
            }
            return providerStatusLines[profile.id] ?? APIKeyStatusLine(text: "API key validated", kind: .success)
        case .saved:
            return APIKeyStatusLine(text: "Saved to Keychain", kind: .success)
        case .invalid(let message):
            return APIKeyStatusLine(text: message, kind: .failure)
        case .revoked(let message):
            return APIKeyStatusLine(text: message, kind: .warning)
        default:
            return nil
        }
    }

    func canSaveProviderAPIKey(profileID: String) -> Bool {
        let draft = providerAPIKeyDrafts[profileID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !draft.isEmpty && !refreshingProviderIDs.contains(profileID)
    }

    func canTestProviderAPIKey(profile: ProviderProfile) -> Bool {
        guard !refreshingProviderIDs.contains(profile.id) else { return false }
        if !profile.requiresAPIKey { return true }
        let draft = providerAPIKeyDrafts[profile.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !draft.isEmpty || providerHasSavedAPIKeyIDs.contains(profile.id)
    }

    func markProviderAPIKeyEdited(profileID: String) {
        providerStatusLines[profileID] = nil
        if providerAPIKeyDrafts[profileID]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            visibleProviderAPIKeyIDs.remove(profileID)
            revealedProviderAPIKeys[profileID] = nil
        }
    }

    func toggleProviderAPIKeyVisibility(profile: ProviderProfile) {
        let draft = providerAPIKeyDrafts[profile.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !draft.isEmpty || providerHasSavedAPIKeyIDs.contains(profile.id) else { return }

        if visibleProviderAPIKeyIDs.contains(profile.id) {
            visibleProviderAPIKeyIDs.remove(profile.id)
            revealedProviderAPIKeys[profile.id] = nil
        } else {
            visibleProviderAPIKeyIDs.insert(profile.id)
            if draft.isEmpty {
                revealedProviderAPIKeys[profile.id] = (try? KeychainHelper.readAPIKey(account: profile.keychainAccount)) ?? ""
            }
        }
    }

    func addManualModel(profileID: String, modelID: String) {
        let trimmed = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = providerProfiles.firstIndex(where: { $0.id == profileID }) else { return }
        if !providerProfiles[index].manualModels.contains(trimmed) {
            providerProfiles[index].manualModels.append(trimmed)
            providerProfiles[index].manualModels.sort()
            persistProviderProfiles()
            recomputeAvailableModels()
        }
    }

    func removeManualModel(profileID: String, modelID: String) {
        guard let index = providerProfiles.firstIndex(where: { $0.id == profileID }) else { return }
        providerProfiles[index].manualModels.removeAll { $0 == modelID }
        persistProviderProfiles()
        recomputeAvailableModels()
    }

    func presentAPIKeyError(_ message: String) {
        providerStatusLines[ProviderProfile.openAIDefaultID] = APIKeyStatusLine(text: message, kind: .failure)
    }

    func discardUnsavedAPIKeyChanges() {
        providerAPIKeyDrafts = [:]
        visibleProviderAPIKeyIDs.removeAll()
        revealedProviderAPIKeys.removeAll()
    }

    func clearCache() {
        ResponseCache.shared.clearAll()
    }

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

    func providerSecretsForUserAction(modelConfigs: [ResolvedFileModelConfig]) throws -> [String: String] {
        var secrets: [String: String] = [:]
        for profile in uniqueProfiles(from: modelConfigs) {
            guard profile.requiresAPIKey else { continue }
            if let draft = providerAPIKeyCandidate(for: profile) {
                secrets[profile.id] = draft
                continue
            }
            secrets[profile.id] = try KeychainHelper.readAPIKey(account: profile.keychainAccount)
        }
        return secrets
    }

    func hasRunnableCredentials(for modelConfigs: [ResolvedFileModelConfig]) -> Bool {
        for config in modelConfigs {
            let profile = config.providerProfile
            guard profile.isEnabled else { return false }
            if profile.requiresAPIKey {
                let draft = providerAPIKeyDrafts[profile.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if draft.isEmpty && !providerHasSavedAPIKeyIDs.contains(profile.id) {
                    return false
                }
            }
        }
        return !modelConfigs.isEmpty
    }

    private func providerAPIKeyCandidate(for profile: ProviderProfile) -> String? {
        let draft = providerAPIKeyDrafts[profile.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !draft.isEmpty {
            return draft
        }
        return try? KeychainHelper.readAPIKey(account: profile.keychainAccount)
    }

    private func observeKeyChanges() {
        NotificationCenter.default.addObserver(
            forName: .quixoteAPIKeyDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshProviderSavedAPIKeyState()
            }
        }
    }

    private func recomputeAvailableModels() {
        var models: [ModelConfig] = []
        for profile in providerProfiles where profile.isEnabled {
            if profile.id == ProviderProfile.openAIDefaultID {
                models += ModelConfig.builtIn.map { model in
                    var copy = model
                    copy.provider = profile.kind
                    copy.providerProfileID = profile.id
                    return copy
                }
            }
            models += profile.availableModelIDs.map { modelID in
                ModelConfig(
                    id: modelID,
                    displayName: displayName(for: modelID),
                    provider: profile.kind,
                    providerProfileID: profile.id,
                    created: nil,
                    supportedReasoningLevels: ModelConfig.supportedReasoningLevels(for: modelID)
                )
            }
        }
        let unique = Dictionary(grouping: models, by: \.selectionKey).compactMap { $0.value.first }
        availableModels = ModelConfig.eligibleTextModels(unique)
        groupedModels = groupedByProvider(availableModels)
    }

    private func refreshProviderSavedAPIKeyState() {
        providerHasSavedAPIKeyIDs = Set(providerProfiles.compactMap { profile in
            guard profile.requiresAPIKey else { return nil }
            return (try? KeychainHelper.readAPIKey(account: profile.keychainAccount)) == nil ? nil : profile.id
        })
    }

    private func modelCount(from text: String) -> Int? {
        guard let first = text.split(separator: " ").first else { return nil }
        return Int(first)
    }

    private func loadProviderProfiles() -> [ProviderProfile] {
        guard let data = UserDefaults.standard.data(forKey: kProviderProfilesKey),
              let decoded = try? JSONDecoder().decode([ProviderProfile].self, from: data) else {
            return ProviderProfile.defaults
        }

        var profilesByID: [String: ProviderProfile] = [:]
        for profile in decoded {
            let fallback = ProviderProfile.defaults.first(where: { $0.id == profile.id })
            profilesByID[profile.id] = profile.sanitized(fallback: fallback)
        }
        for fallback in ProviderProfile.defaults where profilesByID[fallback.id] == nil {
            profilesByID[fallback.id] = fallback
        }
        return ProviderProfile.defaults.compactMap { profilesByID[$0.id]?.sanitized(fallback: $0) }
    }

    private func persistProviderProfiles() {
        guard let data = try? JSONEncoder().encode(providerProfiles) else { return }
        UserDefaults.standard.set(data, forKey: kProviderProfilesKey)
    }

    private func groupedByProvider(_ models: [ModelConfig]) -> [(family: String, models: [ModelConfig])] {
        let profilesByID = providerProfilesByID()
        let grouped = Dictionary(grouping: models) { model in
            let providerName = profilesByID[model.providerProfileID]?.displayName ?? model.provider.displayName
            return "\(providerName) · \(model.family)"
        }
        return grouped
            .map { (family: $0.key, models: ModelConfig.sortedForSelection($0.value)) }
            .sorted { $0.family.localizedStandardCompare($1.family) == .orderedAscending }
    }

    private func displayName(for id: String) -> String {
        id.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func uniqueProfiles(from modelConfigs: [ResolvedFileModelConfig]) -> [ProviderProfile] {
        var seen = Set<String>()
        var profiles: [ProviderProfile] = []
        for config in modelConfigs where !seen.contains(config.providerProfile.id) {
            seen.insert(config.providerProfile.id)
            profiles.append(config.providerProfile)
        }
        return profiles
    }

    private func providerProfilesByID() -> [String: ProviderProfile] {
        var profilesByID: [String: ProviderProfile] = [:]
        for profile in providerProfiles {
            profilesByID[profile.id] = profile
        }
        return profilesByID
    }

}
