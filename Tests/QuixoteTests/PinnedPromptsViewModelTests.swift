import Foundation
import Testing
@testable import Quixote

@MainActor
struct PinnedPromptsViewModelTests {
    @Test
    func firstLoadSeedsDefaultPrompts() {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let viewModel = PinnedPromptsViewModel(
            promptsURL: tempDir.appendingPathComponent("pinned-prompts.json")
        )

        #expect(viewModel.prompts.map(\.name) == [
            "Summarize",
            "Classify sentiment",
            "Extract entities",
            "Translate to English"
        ])
    }

    @Test
    func addUpdateRenameDuplicateDeleteAndPersistRoundTrip() {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("pinned-prompts.json")
        let viewModel = PinnedPromptsViewModel(promptsURL: url)

        let id = viewModel.addPrompt(name: "  Custom  ", systemMessage: "System", template: "{{body}}")
        #expect(viewModel.prompt(for: id)?.name == "Custom")

        viewModel.rename(id: id, name: "   ")
        #expect(viewModel.prompt(for: id)?.name == "New prompt")

        var prompt = viewModel.prompt(for: id)!
        prompt.name = "Edited"
        prompt.systemMessage = "Edited system"
        prompt.template = "Edited template"
        viewModel.update(prompt)

        let duplicateID = viewModel.duplicate(id: id)!
        #expect(viewModel.prompt(for: duplicateID)?.name == "Edited copy")
        #expect(viewModel.prompt(for: duplicateID)?.systemMessage == "Edited system")
        #expect(viewModel.prompt(for: duplicateID)?.template == "Edited template")

        viewModel.delete(id: id)
        #expect(viewModel.prompt(for: id) == nil)

        viewModel.flushPendingSave()
        let reloaded = PinnedPromptsViewModel(promptsURL: url)
        #expect(reloaded.prompt(for: duplicateID)?.name == "Edited copy")
        #expect(reloaded.prompt(for: id) == nil)
    }

    @Test
    func corruptJSONFallsBackToDefaultPrompts() throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("pinned-prompts.json")
        try Data("not json".utf8).write(to: url)

        let viewModel = PinnedPromptsViewModel(promptsURL: url)

        #expect(viewModel.prompts.count == 4)
        #expect(viewModel.prompts.first?.name == "Summarize")
    }

    private func makeTempDir() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
}
