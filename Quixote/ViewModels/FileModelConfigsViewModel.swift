import Foundation

@MainActor
final class FileModelConfigsViewModel: ObservableObject {
    struct FileModelConfigStore: Codable {
        var configsByFile: [UUID: [FileModelConfig]]
    }

    @Published private(set) var configs: [FileModelConfig] = []

    private let persistenceURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Quixote")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("file-model-configs.json")
    }()

    private var configsByFile: [UUID: [FileModelConfig]] = [:]
    private var currentFileID: UUID?
    private var saveTask: Task<Void, Never>?

    init() {
        loadStore()
    }

    func load(
        fileID: UUID,
        availableModels: [ModelConfig],
        legacyModelIDs: [String],
        legacyParameters: LLMParameters
    ) {
        currentFileID = fileID

        var storedConfigs = configsByFile[fileID] ?? []
        if storedConfigs.isEmpty {
            let availableIDs = Set(availableModels.map(\.id))
            let migrated = legacyModelIDs
                .filter { availableIDs.contains($0) }
                .map { modelID in
                    FileModelConfig(fileID: fileID, modelID: modelID, parameters: normalizedParameters(legacyParameters, for: modelID, availableModels: availableModels))
                }
            storedConfigs = migrated.isEmpty ? [defaultConfig(fileID: fileID, availableModels: availableModels)] : migrated
        }

        configs = sanitize(storedConfigs, fileID: fileID, availableModels: availableModels)
        configsByFile[fileID] = configs
        scheduleSave()
    }

    func clear() {
        currentFileID = nil
        configs = []
    }

    func resolvedConfigs(using availableModels: [ModelConfig]) -> [ResolvedFileModelConfig] {
        let resolved = configs.compactMap { config -> (FileModelConfig, ModelConfig)? in
            guard let model = availableModels.first(where: { $0.id == config.modelID }) else { return nil }
            return (config, model)
        }

        let duplicateCounts = Dictionary(grouping: resolved, by: { $0.1.id }).mapValues(\.count)
        var seenCounts: [String: Int] = [:]

        return resolved.map { config, model in
            seenCounts[model.id, default: 0] += 1
            let occurrence = seenCounts[model.id] ?? 1
            let displayName: String
            if duplicateCounts[model.id, default: 0] > 1 {
                displayName = "\(model.displayName) (\(occurrence))"
            } else {
                displayName = model.displayName
            }
            return ResolvedFileModelConfig(
                id: config.id,
                fileID: config.fileID,
                model: model,
                parameters: normalizedParameters(config.parameters, for: model.id, availableModels: availableModels),
                displayName: displayName
            )
        }
    }

    func addModel(modelID: String, availableModels: [ModelConfig]) {
        guard let fileID = currentFileID else { return }
        let base = configs.last?.parameters ?? LLMParameters()
        let config = FileModelConfig(
            fileID: fileID,
            modelID: modelID,
            parameters: normalizedParameters(base, for: modelID, availableModels: availableModels)
        )
        configs.append(config)
        configsByFile[fileID] = configs
        scheduleSave()
    }

    func updateModel(configID: UUID, modelID: String, availableModels: [ModelConfig]) {
        guard let fileID = currentFileID,
              let index = configs.firstIndex(where: { $0.id == configID }) else { return }
        configs[index].modelID = modelID
        configs[index].parameters = normalizedParameters(configs[index].parameters, for: modelID, availableModels: availableModels)
        configsByFile[fileID] = configs
        scheduleSave()
    }

    func updateParameters(configID: UUID, parameters: LLMParameters, availableModels: [ModelConfig]) {
        guard let fileID = currentFileID,
              let index = configs.firstIndex(where: { $0.id == configID }) else { return }
        configs[index].parameters = normalizedParameters(parameters, for: configs[index].modelID, availableModels: availableModels)
        configsByFile[fileID] = configs
        scheduleSave()
    }

    func removeConfig(id: UUID, availableModels: [ModelConfig]) {
        guard let fileID = currentFileID else { return }
        guard configs.count > 1 else { return }
        configs.removeAll { $0.id == id }
        configs = sanitize(configs, fileID: fileID, availableModels: availableModels)
        configsByFile[fileID] = configs
        scheduleSave()
    }

    func removeConfigs(for fileID: UUID) {
        configsByFile.removeValue(forKey: fileID)
        if currentFileID == fileID {
            clear()
        }
        scheduleSave()
    }

    func ensureAvailableModelsAreValid(_ availableModels: [ModelConfig]) {
        guard let fileID = currentFileID else { return }
        configs = sanitize(configs, fileID: fileID, availableModels: availableModels)
        configsByFile[fileID] = configs
        scheduleSave()
    }

    private func defaultConfig(fileID: UUID, availableModels: [ModelConfig]) -> FileModelConfig {
        let fallbackModelID = availableModels.first?.id ?? ModelConfig.builtIn.first?.id ?? "gpt-4o-mini"
        return FileModelConfig(fileID: fileID, modelID: fallbackModelID, parameters: normalizedParameters(LLMParameters(), for: fallbackModelID, availableModels: availableModels))
    }

    private func sanitize(_ configs: [FileModelConfig], fileID: UUID, availableModels: [ModelConfig]) -> [FileModelConfig] {
        guard !availableModels.isEmpty else { return configs }
        let fallbackModelID = availableModels.first?.id ?? "gpt-4o-mini"
        let availableIDs = Set(availableModels.map(\.id))

        let sanitized = configs.map { config in
            let modelID = availableIDs.contains(config.modelID) ? config.modelID : fallbackModelID
            return FileModelConfig(
                id: config.id,
                fileID: fileID,
                modelID: modelID,
                parameters: normalizedParameters(config.parameters, for: modelID, availableModels: availableModels)
            )
        }

        return sanitized.isEmpty ? [defaultConfig(fileID: fileID, availableModels: availableModels)] : sanitized
    }

    private func normalizedParameters(
        _ parameters: LLMParameters,
        for modelID: String,
        availableModels: [ModelConfig]
    ) -> LLMParameters {
        var normalized = parameters
        normalized.frequencyPenalty = 0
        normalized.presencePenalty = 0

        let supportedLevels = availableModels.first(where: { $0.id == modelID })?.supportedReasoningLevels
            ?? ModelConfig.supportedReasoningLevels(for: modelID)
        if let effort = normalized.reasoningEffort, !supportedLevels.contains(effort) {
            normalized.reasoningEffort = nil
        }

        normalized.temperature = min(max(normalized.temperature, 0), 2)
        normalized.topP = min(max(normalized.topP, 0), 1)
        if let maxTokens = normalized.maxTokens, maxTokens <= 0 {
            normalized.maxTokens = nil
        }
        return normalized
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            persistStore()
        }
    }

    private func persistStore() {
        let store = FileModelConfigStore(configsByFile: configsByFile)
        let data = try? JSONEncoder().encode(store)
        try? data?.write(to: persistenceURL, options: .atomic)
    }

    private func loadStore() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let store = try? JSONDecoder().decode(FileModelConfigStore.self, from: data) else { return }
        configsByFile = store.configsByFile
    }
}
