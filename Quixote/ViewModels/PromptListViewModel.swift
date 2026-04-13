import Foundation

@MainActor
final class PromptListViewModel: ObservableObject {
    struct PromptListStore: Codable {
        var promptsByFile: [UUID: [Prompt]]
        var selectedPromptIDs: [UUID: UUID]
    }

    @Published private(set) var prompts: [Prompt] = []
    @Published var selectedPromptID: UUID?

    private let promptsURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Quixote")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("prompts.json")
    }()

    private var promptsByFile: [UUID: [Prompt]] = [:]
    private var selectedPromptIDs: [UUID: UUID] = [:]
    private var currentFileID: UUID?
    private var saveTask: Task<Void, Never>?

    var selectedPrompt: Prompt? {
        prompts.first { $0.id == selectedPromptID }
    }

    init() {
        loadStore()
    }

    func load(fileID: UUID) {
        currentFileID = fileID

        var storedPrompts = promptsByFile[fileID] ?? []
        if storedPrompts.isEmpty {
            storedPrompts = [Prompt(fileID: fileID)]
            promptsByFile[fileID] = storedPrompts
        }

        prompts = storedPrompts

        let preferredSelection = selectedPromptIDs[fileID]
        if let preferredSelection,
           prompts.contains(where: { $0.id == preferredSelection }) {
            selectedPromptID = preferredSelection
        } else {
            selectedPromptID = prompts.first?.id
        }

        if let selectedPromptID {
            selectedPromptIDs[fileID] = selectedPromptID
        }

        saveStore()
    }

    func clear() {
        currentFileID = nil
        prompts = []
        selectedPromptID = nil
    }

    func addPrompt() {
        guard let fileID = currentFileID else { return }

        let prompt = Prompt(fileID: fileID, name: nextPromptName())
        prompts.append(prompt)
        promptsByFile[fileID] = prompts
        selectedPromptID = prompt.id
        selectedPromptIDs[fileID] = prompt.id
        saveStore()
    }

    func renamePrompt(id: UUID, name: String) {
        guard let fileID = currentFileID,
              let index = prompts.firstIndex(where: { $0.id == id }) else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        prompts[index].name = trimmed.isEmpty ? "Prompt" : trimmed
        prompts[index].updatedAt = Date()
        promptsByFile[fileID] = prompts
        saveStore()
    }

    func updatePrompt(_ prompt: Prompt) {
        guard let fileID = currentFileID,
              let index = prompts.firstIndex(where: { $0.id == prompt.id }) else { return }

        prompts[index] = prompt
        promptsByFile[fileID] = prompts
        saveStore()
    }

    func selectPrompt(_ id: UUID?) {
        guard let fileID = currentFileID else { return }

        guard let id, prompts.contains(where: { $0.id == id }) else {
            selectedPromptID = prompts.first?.id
            if let selectedPromptID {
                selectedPromptIDs[fileID] = selectedPromptID
            }
            saveStore()
            return
        }

        selectedPromptID = id
        selectedPromptIDs[fileID] = id
        saveStore()
    }

    func deleteSelectedPrompt() {
        guard let fileID = currentFileID,
              let selectedPromptID,
              let index = prompts.firstIndex(where: { $0.id == selectedPromptID }) else { return }

        prompts.remove(at: index)
        if prompts.isEmpty {
            let replacement = Prompt(fileID: fileID)
            prompts = [replacement]
        }

        let nextIndex = min(index, prompts.count - 1)
        self.selectedPromptID = prompts[nextIndex].id
        promptsByFile[fileID] = prompts
        selectedPromptIDs[fileID] = prompts[nextIndex].id
        saveStore()
    }

    func moveSelectedPromptUp() {
        moveSelectedPrompt(by: -1)
    }

    func moveSelectedPromptDown() {
        moveSelectedPrompt(by: 1)
    }

    func removePrompts(for fileID: UUID) {
        promptsByFile.removeValue(forKey: fileID)
        selectedPromptIDs.removeValue(forKey: fileID)
        if currentFileID == fileID {
            clear()
        }
        saveStore()
    }

    private func moveSelectedPrompt(by offset: Int) {
        guard let fileID = currentFileID,
              let selectedPromptID,
              let currentIndex = prompts.firstIndex(where: { $0.id == selectedPromptID }) else { return }

        let targetIndex = currentIndex + offset
        guard prompts.indices.contains(targetIndex) else { return }

        let prompt = prompts.remove(at: currentIndex)
        prompts.insert(prompt, at: targetIndex)
        promptsByFile[fileID] = prompts
        selectedPromptIDs[fileID] = selectedPromptID
        saveStore()
    }

    private func nextPromptName() -> String {
        let existingNames = Set(prompts.map(\.name))
        var index = 1
        while true {
            let candidate = "Prompt \(index)"
            if !existingNames.contains(candidate) {
                return candidate
            }
            index += 1
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            persistStore()
        }
    }

    private func saveStore() {
        scheduleSave()
    }

    private func persistStore() {
        let store = PromptListStore(promptsByFile: promptsByFile, selectedPromptIDs: selectedPromptIDs)
        let data = try? JSONEncoder().encode(store)
        try? data?.write(to: promptsURL, options: .atomic)
    }

    private func loadStore() {
        guard let data = try? Data(contentsOf: promptsURL) else { return }

        if let store = try? JSONDecoder().decode(PromptListStore.self, from: data) {
            promptsByFile = store.promptsByFile
            selectedPromptIDs = store.selectedPromptIDs
            return
        }

        if let legacy = try? JSONDecoder().decode([UUID: Prompt].self, from: data) {
            promptsByFile = legacy.reduce(into: [:]) { partialResult, entry in
                partialResult[entry.key] = [entry.value]
            }
            selectedPromptIDs = legacy.reduce(into: [:]) { partialResult, entry in
                partialResult[entry.key] = entry.value.id
            }
            persistStore()
        }
    }
}
