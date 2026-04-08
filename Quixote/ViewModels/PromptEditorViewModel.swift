import Foundation
import Combine

@MainActor
final class PromptEditorViewModel: ObservableObject {
    @Published var prompt: Prompt?
    @Published var previewText: String = ""

    private var table: ParsedTable = .empty
    private var saveTask: Task<Void, Never>? = nil

    private let promptsURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Quixote")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("prompts.json")
    }()

    private var allPrompts: [UUID: Prompt] = [:]

    init() {
        loadAll()
    }

    // MARK: - Load / switch file

    func load(fileID: UUID, table: ParsedTable) {
        self.table = table
        if let existing = allPrompts[fileID] {
            prompt = existing
        } else {
            let p = Prompt(fileID: fileID)
            allPrompts[fileID] = p
            prompt = p
            saveAll()
        }
        refreshPreview()
    }

    func clear() {
        prompt = nil
        previewText = ""
        table = .empty
    }

    // MARK: - Editing

    func updateTemplate(_ text: String) {
        guard prompt != nil else { return }
        prompt!.template = text
        prompt!.updatedAt = Date()
        allPrompts[prompt!.fileID] = prompt
        refreshPreview()
        scheduleSave()
    }

    func updateParameters(_ params: LLMParameters) {
        guard prompt != nil else { return }
        prompt!.parameters = params
        prompt!.updatedAt = Date()
        allPrompts[prompt!.fileID] = prompt
        scheduleSave()
    }

    func insertToken(_ columnName: String) {
        guard prompt != nil else { return }
        prompt!.template += "{{\(columnName)}}"
        prompt!.updatedAt = Date()
        allPrompts[prompt!.fileID] = prompt
        refreshPreview()
        scheduleSave()
    }

    // MARK: - Preview

    var previewRow: Row? { table.rows.first }

    private func refreshPreview() {
        guard let p = prompt else { previewText = ""; return }
        previewText = InterpolationEngine.preview(template: p.template, table: table)
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            saveAll()
        }
    }

    private func saveAll() {
        let data = try? JSONEncoder().encode(allPrompts)
        try? data?.write(to: promptsURL, options: .atomic)
    }

    private func loadAll() {
        guard let data = try? Data(contentsOf: promptsURL),
              let saved = try? JSONDecoder().decode([UUID: Prompt].self, from: data) else { return }
        allPrompts = saved
    }
}
