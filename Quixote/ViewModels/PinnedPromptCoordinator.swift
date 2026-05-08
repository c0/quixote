import Foundation

struct PendingPinnedPromptApplication: Equatable {
    let pin: PinnedPrompt
    let fileID: UUID
}

@MainActor
struct PinnedPromptCoordinator {
    let pinnedPrompts: PinnedPromptsViewModel
    let promptList: PromptListViewModel

    func addPin() -> UUID {
        pinnedPrompts.addPrompt()
    }

    func duplicatePin(id: UUID) -> UUID? {
        pinnedPrompts.duplicate(id: id)
    }

    func deletePin(id: UUID) {
        pinnedPrompts.delete(id: id)
        promptList.removePinnedPromptReferences(pinnedPromptID: id)
    }

    func pinCurrentTab() {
        guard let prompt = promptList.selectedPrompt,
              prompt.pinnedPromptID == nil,
              !prompt.isPinned else { return }

        let pinID = pinnedPrompts.addPrompt(
            name: prompt.name,
            systemMessage: prompt.systemMessage,
            template: prompt.template
        )
        promptList.markCurrentPromptAsPinned(pinnedPromptID: pinID)
    }

    func apply(_ application: PendingPinnedPromptApplication) {
        promptList.addPromptFromPin(
            name: application.pin.name,
            systemMessage: application.pin.systemMessage,
            template: application.pin.template,
            fromPinID: application.pin.id,
            fromPinName: application.pin.name
        )
    }
}
