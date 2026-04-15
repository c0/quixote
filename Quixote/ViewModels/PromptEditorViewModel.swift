import Foundation

@MainActor
final class PromptEditorViewModel: ObservableObject {
    @Published var prompt: Prompt?
    @Published var previewText: String = ""

    var onPromptUpdated: ((Prompt) -> Void)?

    private var table: ParsedTable = .empty

    func load(prompt: Prompt?, table: ParsedTable) {
        self.prompt = prompt
        self.table = table
        refreshPreview()
    }

    func clear() {
        prompt = nil
        previewText = ""
        table = .empty
    }

    func updateTemplate(_ text: String) {
        guard var prompt else { return }
        prompt.template = text
        prompt.updatedAt = Date()
        self.prompt = prompt
        refreshPreview()
        onPromptUpdated?(prompt)
    }

    func updateParameters(_ params: LLMParameters) {
        guard var prompt else { return }
        prompt.parameters = params
        prompt.updatedAt = Date()
        self.prompt = prompt
        onPromptUpdated?(prompt)
    }

    func updateSystemMessage(_ text: String) {
        guard var prompt else { return }
        prompt.systemMessage = text
        prompt.updatedAt = Date()
        self.prompt = prompt
        onPromptUpdated?(prompt)
    }

    func insertToken(_ columnName: String) {
        guard var prompt else { return }
        prompt.template += "{{\(columnName)}}"
        prompt.updatedAt = Date()
        self.prompt = prompt
        refreshPreview()
        onPromptUpdated?(prompt)
    }

    var previewRow: Row? { table.rows.first }

    private func refreshPreview() {
        guard let prompt else {
            previewText = ""
            return
        }
        previewText = InterpolationEngine.preview(template: prompt.template, table: table)
    }
}
