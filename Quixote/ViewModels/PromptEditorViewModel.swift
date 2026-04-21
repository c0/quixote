import Foundation

@MainActor
final class PromptEditorViewModel: ObservableObject {
    @Published var prompt: Prompt?
    @Published var previewText: String = ""

    var onPromptUpdated: ((Prompt) -> Void)?

    private var table: ParsedTable = .empty
    private var previewColumns: [ColumnDef]?

    func load(prompt: Prompt?, table: ParsedTable, previewColumns: [ColumnDef]? = nil) {
        self.prompt = prompt
        self.table = table
        self.previewColumns = previewColumns
        refreshPreview()
    }

    func updatePreviewColumns(_ columns: [ColumnDef]) {
        previewColumns = columns
        refreshPreview()
    }

    func clear() {
        prompt = nil
        previewText = ""
        table = .empty
        previewColumns = nil
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

    func removeToken(_ columnName: String) {
        guard var prompt else { return }
        let token = "{{\(columnName)}}"
        guard let range = prompt.template.range(of: token, options: .backwards) else { return }
        if let lineRange = removableVariableLineRange(containing: range, in: prompt.template, token: token) {
            prompt.template.removeSubrange(lineRange)
        } else {
            prompt.template.removeSubrange(range)
        }
        prompt.updatedAt = Date()
        self.prompt = prompt
        refreshPreview()
        onPromptUpdated?(prompt)
    }

    var previewRow: Row? { table.rows.first }

    private func removableVariableLineRange(
        containing tokenRange: Range<String.Index>,
        in template: String,
        token: String
    ) -> Range<String.Index>? {
        let lineRange = template.lineRange(for: tokenRange)
        let line = String(template[lineRange])
        guard line.filter({ $0 == "{" }).count == 2,
              line.filter({ $0 == "}" }).count == 2 else {
            return nil
        }

        let remainder = line.replacingOccurrences(of: token, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard remainder.isEmpty || remainder.hasSuffix(":") else {
            return nil
        }
        return lineRange
    }

    private func refreshPreview() {
        guard let prompt else {
            previewText = ""
            return
        }
        previewText = InterpolationEngine.preview(template: prompt.template, table: table, columns: previewColumns)
    }
}
