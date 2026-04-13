import SwiftUI

struct PromptListView: View {
    @ObservedObject var viewModel: PromptListViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if viewModel.prompts.isEmpty {
                ContentUnavailableView(
                    "No Prompts",
                    systemImage: "text.badge.plus",
                    description: Text("Add a prompt to start building prompt variants for this file.")
                )
            } else {
                List(selection: selectionBinding) {
                    ForEach(viewModel.prompts) { prompt in
                        TextField(
                            "Prompt",
                            text: Binding(
                                get: { prompt.name },
                                set: { viewModel.renamePrompt(id: prompt.id, name: $0) }
                            )
                        )
                        .textFieldStyle(.plain)
                        .tag(prompt.id)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedPromptID },
            set: { viewModel.selectPrompt($0) }
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Prompts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                viewModel.moveSelectedPromptUp()
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.plain)
            .help("Move selected prompt up")
            .disabled(!canMoveSelectedPromptUp)

            Button {
                viewModel.moveSelectedPromptDown()
            } label: {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(.plain)
            .help("Move selected prompt down")
            .disabled(!canMoveSelectedPromptDown)

            Button {
                viewModel.deleteSelectedPrompt()
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.plain)
            .help("Delete selected prompt")
            .disabled(viewModel.prompts.isEmpty)

            Button {
                viewModel.addPrompt()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .help("Add prompt")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var canMoveSelectedPromptUp: Bool {
        guard let selectedPromptID = viewModel.selectedPromptID,
              let index = viewModel.prompts.firstIndex(where: { $0.id == selectedPromptID }) else {
            return false
        }
        return index > 0
    }

    private var canMoveSelectedPromptDown: Bool {
        guard let selectedPromptID = viewModel.selectedPromptID,
              let index = viewModel.prompts.firstIndex(where: { $0.id == selectedPromptID }) else {
            return false
        }
        return index < viewModel.prompts.count - 1
    }
}
