import SwiftUI

private let kConcurrencyKey = "quixote.concurrency"
private let kRateLimitKey = "quixote.rateLimit"
private let kMaxRetriesKey = "quixote.maxRetries"
private let kShowExtrapolationKey = "quixote.showExtrapolation"
private let kExtrapolationScaleKey = "quixote.extrapolationScale"
private let kShowCosineSimilarityKey = "quixote.showCosineSimilarity"
private let kShowRougeMetricsKey = "quixote.showRougeMetrics"
private let kHasSavedOpenAIKey = "quixote.hasSavedOpenAIKey"
private let kLegacyPlaintextAPIKey = "quixote.openai.apiKey"

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

enum APIKeyInlineIndicator: Equatable {
    case none
    case spinner
    case success
    case failure
    case warning
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
    private enum ValidationMarker {
        case none
        case validating
        case valid(modelCount: Int?)
        case saved
        case invalid(String)
        case revoked(String)
    }

    @Published var openAIKey: String = ""
    @Published var isKeyVisible = false
    @Published private(set) var apiKeyUIState: APIKeyUIState = .blank

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

    @Published private(set) var hasSavedAPIKey: Bool = UserDefaults.standard.bool(forKey: kHasSavedOpenAIKey)
    @Published var availableModels: [ModelConfig] = ModelConfig.builtIn
    @Published var groupedModels: [(family: String, models: [ModelConfig])] = ModelConfig.grouped(ModelConfig.builtIn)

    private var validationMarker: ValidationMarker = .none
    private var isKeyFieldFocused = false
    private var revealedSavedKey = ""

    init() {
        UserDefaults.standard.removeObject(forKey: kLegacyPlaintextAPIKey)
        observeKeyChanges()
        recomputeAPIKeyUIState()
    }

    var isValidatingKey: Bool {
        if case .validating = validationMarker { return true }
        return false
    }

    var showsEyeToggle: Bool {
        hasSavedAPIKey || !trimmedDraftKey.isEmpty
    }

    var canSaveAPIKey: Bool {
        !trimmedDraftKey.isEmpty && !isValidatingKey
    }

    var canTestAPIKey: Bool {
        (!trimmedDraftKey.isEmpty || hasSavedAPIKey) && !isValidatingKey
    }

    var saveButtonUsesPrimaryStyle: Bool {
        isKeyFieldFocused || !trimmedDraftKey.isEmpty
    }

    var apiKeyDisplayText: String {
        switch apiKeyUIState {
        case .blank, .focused:
            return ""
        case .typing:
            return openAIKey
        case .masked, .validating, .valid, .saved, .invalid, .revoked:
            return String(repeating: "•", count: 20)
        case .reveal:
            if !trimmedDraftKey.isEmpty { return openAIKey }
            return revealedSavedKey
        }
    }

    var apiKeyPlaceholder: String {
        switch apiKeyUIState {
        case .blank, .focused:
            return "sk-..."
        default:
            return ""
        }
    }

    var showsEditableTextField: Bool {
        switch apiKeyUIState {
        case .blank, .focused, .typing:
            return true
        case .reveal:
            return !trimmedDraftKey.isEmpty
        default:
            return false
        }
    }

    var editableTextColor: Color {
        trimmedDraftKey.isEmpty ? .quixoteTextMuted : .quixoteTextSecondary
    }

    var displayTextColor: Color {
        switch apiKeyUIState {
        case .blank, .focused:
            return .quixoteTextMuted
        case .invalid:
            return .quixoteTextSecondary
        case .revoked:
            return .quixoteTextSecondary
        default:
            return .quixoteTextSecondary
        }
    }

    var usesMaskedLetterSpacing: Bool {
        switch apiKeyUIState {
        case .masked, .validating, .valid, .saved, .invalid, .revoked:
            return true
        default:
            return false
        }
    }

    var inlineIndicator: APIKeyInlineIndicator {
        switch apiKeyUIState {
        case .validating:
            return .spinner
        case .valid, .saved:
            return .success
        case .invalid:
            return .failure
        case .revoked:
            return .warning
        default:
            return .none
        }
    }

    var statusLine: APIKeyStatusLine? {
        switch apiKeyUIState {
        case .validating:
            return APIKeyStatusLine(text: "Validating key…", kind: .neutral)
        case .valid(let modelCount):
            if let modelCount {
                return APIKeyStatusLine(text: "\(modelCount) models available · validated just now", kind: .success)
            }
            return APIKeyStatusLine(text: "API key validated", kind: .success)
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

    var keyFieldBorderColor: Color {
        switch apiKeyUIState {
        case .focused, .typing, .validating:
            return .quixoteBlue
        case .valid, .saved:
            return .quixoteGreen
        case .invalid:
            return .quixoteRed
        case .revoked:
            return .quixoteOrange
        default:
            return .quixoteDivider
        }
    }

    var keyFieldRingColor: Color {
        switch apiKeyUIState {
        case .focused, .typing, .validating:
            return .quixoteBlue.opacity(0.22)
        case .valid, .saved:
            return .quixoteGreen.opacity(0.18)
        case .invalid:
            return .quixoteRed.opacity(0.20)
        case .revoked:
            return .quixoteOrange.opacity(0.18)
        default:
            return .clear
        }
    }

    @discardableResult
    func saveKey() -> Bool {
        let trimmed = trimmedDraftKey
        guard !trimmed.isEmpty else {
            presentAPIKeyError("Enter an API key first")
            return false
        }

        do {
            try KeychainHelper.saveOpenAIKey(trimmed)
            openAIKey = ""
            isKeyVisible = false
            revealedSavedKey = ""
            setHasSavedAPIKey(true)
            validationMarker = .saved
            recomputeAPIKeyUIState()
            NotificationCenter.default.post(name: .quixoteAPIKeyDidChange, object: nil)
            return true
        } catch {
            presentAPIKeyError(error.localizedDescription)
            return false
        }
    }

    func validateKey() {
        let typedDraft = trimmedDraftKey
        let isValidatingSavedKey = typedDraft.isEmpty

        let keyToValidate: String
        do {
            keyToValidate = try apiKeyForUserAction(preferUnsavedInput: true)
        } catch {
            presentAPIKeyError(error.localizedDescription)
            return
        }

        guard !keyToValidate.isEmpty else {
            presentAPIKeyError("Enter an API key first")
            return
        }

        validationMarker = .validating
        isKeyVisible = false
        revealedSavedKey = ""
        recomputeAPIKeyUIState()

        Task {
            defer {
                if case .validating = self.validationMarker {
                    self.validationMarker = .none
                    self.recomputeAPIKeyUIState()
                }
            }

            do {
                var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
                request.setValue("Bearer \(keyToValidate)", forHTTPHeaderField: "Authorization")
                let (_, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    self.presentAPIKeyError("Unexpected response — try again")
                    return
                }

                switch http.statusCode {
                case 200:
                    let models = try? await OpenAIService.fetchModels(apiKey: keyToValidate)
                    if let models {
                        self.updateAvailableModels(models)
                    }
                    self.validationMarker = .valid(modelCount: models?.count)
                    self.recomputeAPIKeyUIState()
                case 401:
                    if isValidatingSavedKey && self.hasSavedAPIKey {
                        self.validationMarker = .revoked("Key may be revoked — requests are failing")
                    } else {
                        self.validationMarker = .invalid("Invalid API key — check your key and try again")
                    }
                    self.recomputeAPIKeyUIState()
                default:
                    self.validationMarker = .invalid("Unexpected response — try again")
                    self.recomputeAPIKeyUIState()
                }
            } catch {
                self.presentAPIKeyError("Network error: \(error.localizedDescription)")
            }
        }
    }

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
        validationMarker = .none
        recomputeAPIKeyUIState()
    }

    func updateKeyFieldFocus(_ focused: Bool) {
        isKeyFieldFocused = focused
        recomputeAPIKeyUIState()
    }

    func toggleKeyVisibility() {
        guard showsEyeToggle else { return }
        isKeyVisible.toggle()

        if isKeyVisible, trimmedDraftKey.isEmpty, hasSavedAPIKey {
            revealedSavedKey = (try? KeychainHelper.readOpenAIKey()) ?? ""
        } else if !isKeyVisible {
            revealedSavedKey = ""
        }

        validationMarker = .none
        recomputeAPIKeyUIState()
    }

    func presentAPIKeyError(_ message: String) {
        validationMarker = .invalid(message)
        recomputeAPIKeyUIState()
    }

    func discardUnsavedAPIKeyChanges() {
        openAIKey = ""
        isKeyVisible = false
        isKeyFieldFocused = false
        revealedSavedKey = ""
        validationMarker = .none
        recomputeAPIKeyUIState()
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

    func apiKeyForUserAction(preferUnsavedInput: Bool = false) throws -> String {
        if preferUnsavedInput, !trimmedDraftKey.isEmpty {
            return trimmedDraftKey
        }
        return try KeychainHelper.readOpenAIKey()
    }

    private var trimmedDraftKey: String {
        openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func observeKeyChanges() {
        NotificationCenter.default.addObserver(
            forName: .quixoteAPIKeyDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.hasSavedAPIKey = UserDefaults.standard.bool(forKey: kHasSavedOpenAIKey)
                if !self.hasSavedAPIKey {
                    self.isKeyVisible = false
                    self.revealedSavedKey = ""
                }
                if case .saved = self.validationMarker {
                    // preserve saved state
                } else {
                    self.validationMarker = .none
                }
                self.recomputeAPIKeyUIState()
            }
        }
    }

    private func updateAvailableModels(_ models: [ModelConfig]) {
        let eligibleModels = ModelConfig.eligibleTextModels(models)
        availableModels = eligibleModels.isEmpty ? ModelConfig.builtIn : eligibleModels
        groupedModels = ModelConfig.grouped(availableModels)
    }

    private func setHasSavedAPIKey(_ hasSaved: Bool) {
        hasSavedAPIKey = hasSaved
        UserDefaults.standard.set(hasSaved, forKey: kHasSavedOpenAIKey)
    }

    private func recomputeAPIKeyUIState() {
        switch validationMarker {
        case .validating:
            apiKeyUIState = .validating
            return
        case .valid(let count):
            apiKeyUIState = .valid(modelCount: count)
            return
        case .saved:
            apiKeyUIState = .saved
            return
        case .invalid(let message):
            apiKeyUIState = .invalid(message)
            return
        case .revoked(let message):
            apiKeyUIState = .revoked(message)
            return
        case .none:
            break
        }

        if !trimmedDraftKey.isEmpty {
            if isKeyVisible {
                apiKeyUIState = .reveal
            } else if isKeyFieldFocused {
                apiKeyUIState = .typing
            } else {
                apiKeyUIState = .masked
            }
            return
        }

        if hasSavedAPIKey {
            apiKeyUIState = isKeyVisible ? .reveal : .masked
            return
        }

        apiKeyUIState = isKeyFieldFocused ? .focused : .blank
    }
}
