import Foundation
import Testing
@testable import Quixote

@MainActor
struct PromptListPinnedPromptTests {
    @Test
    func addPromptFromPinStoresAttributionAndPinIdentity() {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let promptList = PromptListViewModel(promptsURL: tempDir.appendingPathComponent("prompts.json"))
        let fileID = UUID()
        let pinID = UUID()

        promptList.load(fileID: fileID)
        promptList.addPromptFromPin(
            name: "Summarize",
            systemMessage: "System",
            template: "{{body}}",
            fromPinID: pinID,
            fromPinName: "Pinned Summarize"
        )

        let prompt = promptList.selectedPrompt
        #expect(prompt?.name == "Summarize")
        #expect(prompt?.systemMessage == "System")
        #expect(prompt?.template == "{{body}}")
        #expect(prompt?.fromPinID == pinID)
        #expect(prompt?.fromPinName == "Pinned Summarize")
        #expect(prompt?.pinnedPromptID == pinID)
        #expect(prompt?.isPinned == true)
    }

    @Test
    func markCurrentPromptAsPinnedDoesNotSetFromAttribution() {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let promptList = PromptListViewModel(promptsURL: tempDir.appendingPathComponent("prompts.json"))
        let fileID = UUID()
        let pinID = UUID()

        promptList.load(fileID: fileID)
        promptList.markCurrentPromptAsPinned(pinnedPromptID: pinID)

        let prompt = promptList.selectedPrompt
        #expect(prompt?.pinnedPromptID == pinID)
        #expect(prompt?.isPinned == true)
        #expect(prompt?.fromPinID == nil)
        #expect(prompt?.fromPinName == nil)
    }

    @Test
    func removePinnedPromptReferencesClearsPinStateAcrossFilesButKeepsAttributionSnapshot() {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let promptList = PromptListViewModel(promptsURL: tempDir.appendingPathComponent("prompts.json"))
        let firstFileID = UUID()
        let secondFileID = UUID()
        let pinID = UUID()

        promptList.load(fileID: firstFileID)
        promptList.addPromptFromPin(
            name: "Pinned",
            systemMessage: "System",
            template: "Template",
            fromPinID: pinID,
            fromPinName: "Original Pin Name"
        )

        promptList.load(fileID: secondFileID)
        promptList.addPromptFromPin(
            name: "Pinned",
            systemMessage: "System",
            template: "Template",
            fromPinID: pinID,
            fromPinName: "Original Pin Name"
        )

        promptList.removePinnedPromptReferences(pinnedPromptID: pinID)

        #expect(promptList.selectedPrompt?.pinnedPromptID == nil)
        #expect(promptList.selectedPrompt?.isPinned == false)
        #expect(promptList.selectedPrompt?.fromPinID == pinID)
        #expect(promptList.selectedPrompt?.fromPinName == "Original Pin Name")

        promptList.load(fileID: firstFileID)
        #expect(promptList.selectedPrompt?.pinnedPromptID == nil)
        #expect(promptList.selectedPrompt?.isPinned == false)
        #expect(promptList.selectedPrompt?.fromPinID == pinID)
        #expect(promptList.selectedPrompt?.fromPinName == "Original Pin Name")
    }

    @Test
    func deleteSelectedPromptFallsBackToAValidSelection() {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let promptList = PromptListViewModel(promptsURL: tempDir.appendingPathComponent("prompts.json"))
        let fileID = UUID()

        promptList.load(fileID: fileID)
        let originalID = promptList.selectedPromptID
        promptList.addPrompt()
        let addedID = promptList.selectedPromptID

        promptList.deletePrompt(id: addedID!)

        #expect(promptList.selectedPromptID == originalID)
        #expect(promptList.selectedPrompt != nil)
    }

    @Test
    func coordinatorPinsCurrentTabAndDeleteCleansReferences() {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let promptList = PromptListViewModel(promptsURL: tempDir.appendingPathComponent("prompts.json"))
        let pinnedPrompts = PinnedPromptsViewModel(promptsURL: tempDir.appendingPathComponent("pinned-prompts.json"))
        let coordinator = PinnedPromptCoordinator(pinnedPrompts: pinnedPrompts, promptList: promptList)
        let fileID = UUID()

        promptList.load(fileID: fileID)
        var prompt = promptList.selectedPrompt!
        prompt.name = "Reusable"
        prompt.systemMessage = "System"
        prompt.template = "Template"
        promptList.updatePrompt(prompt)

        coordinator.pinCurrentTab()

        let pinID = promptList.selectedPrompt?.pinnedPromptID
        #expect(pinID != nil)
        #expect(promptList.selectedPrompt?.isPinned == true)
        #expect(promptList.selectedPrompt?.fromPinName == nil)
        #expect(pinnedPrompts.prompt(for: pinID!)?.name == "Reusable")

        coordinator.deletePin(id: pinID!)

        #expect(pinnedPrompts.prompt(for: pinID!) == nil)
        #expect(promptList.selectedPrompt?.pinnedPromptID == nil)
        #expect(promptList.selectedPrompt?.isPinned == false)
    }

    @Test
    func coordinatorApplyCreatesDatasetPromptFromPendingApplication() {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let promptList = PromptListViewModel(promptsURL: tempDir.appendingPathComponent("prompts.json"))
        let pinnedPrompts = PinnedPromptsViewModel(promptsURL: tempDir.appendingPathComponent("pinned-prompts.json"))
        let coordinator = PinnedPromptCoordinator(pinnedPrompts: pinnedPrompts, promptList: promptList)
        let fileID = UUID()
        let pin = PinnedPrompt(name: "Apply Me", systemMessage: "System", template: "{{body}}")

        promptList.load(fileID: fileID)
        coordinator.apply(PendingPinnedPromptApplication(pin: pin, fileID: fileID))

        #expect(promptList.selectedPrompt?.name == "Apply Me")
        #expect(promptList.selectedPrompt?.fromPinID == pin.id)
        #expect(promptList.selectedPrompt?.fromPinName == "Apply Me")
        #expect(promptList.selectedPrompt?.pinnedPromptID == pin.id)
    }

    private func makeTempDir() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
}
