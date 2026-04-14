import SwiftUI

struct PromptEditorView: View {
    private enum EditorMode: String, CaseIterable {
        case write
        case preview
    }

    @ObservedObject var viewModel: PromptEditorViewModel
    @ObservedObject var promptList: PromptListViewModel
    let columns: [ColumnDef]

    @State private var editorMode: EditorMode = .write
    @State private var showParameters = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if !columns.isEmpty {
                Divider()
                tokenShelf
            }
            Divider()
            content
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            promptTabs

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField(
                        "Prompt",
                        text: Binding(
                            get: { viewModel.prompt?.name ?? "" },
                            set: { newValue in
                                if let promptID = viewModel.prompt?.id {
                                    promptList.renamePrompt(id: promptID, name: newValue)
                                }
                            }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.semibold))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $editorMode) {
                    Text("Write").tag(EditorMode.write)
                    Text("Preview").tag(EditorMode.preview)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                Toggle(isOn: $showParameters) {
                    Image(systemName: "slider.horizontal.3")
                }
                .toggleStyle(.button)
                .help("LLM parameters")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var promptTabs: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(promptList.prompts) { prompt in
                        Button {
                            promptList.selectPrompt(prompt.id)
                        } label: {
                            Text(prompt.name)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(prompt.id == promptList.selectedPromptID ? Color.accentColor : Color.secondary.opacity(0.10))
                                .foregroundStyle(prompt.id == promptList.selectedPromptID ? Color.white : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help(prompt.name)
                    }
                }
            }

            Divider().frame(height: 16)

            Button {
                promptList.moveSelectedPromptUp()
            } label: {
                Image(systemName: "arrow.left")
            }
            .buttonStyle(.plain)
            .disabled(!canMoveSelectedPromptLeft)

            Button {
                promptList.moveSelectedPromptDown()
            } label: {
                Image(systemName: "arrow.right")
            }
            .buttonStyle(.plain)
            .disabled(!canMoveSelectedPromptRight)

            Button {
                promptList.deleteSelectedPrompt()
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.plain)
            .disabled(promptList.prompts.isEmpty)

            Button {
                promptList.addPrompt()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
        }
    }

    private var subtitle: String {
        if editorMode == .preview {
            if let previewRow = viewModel.previewRow {
                return "Previewing with row \(previewRow.index + 1) from the current file."
            }
            return "Preview becomes available when a file with rows is loaded."
        }

        if columns.isEmpty {
            return "Write the template that will run for each selected row."
        }

        return "Write the template that will run for each selected row. \(columns.count) columns ready to insert."
    }

    private var canMoveSelectedPromptLeft: Bool {
        guard let selectedPromptID = promptList.selectedPromptID,
              let index = promptList.prompts.firstIndex(where: { $0.id == selectedPromptID }) else {
            return false
        }
        return index > 0
    }

    private var canMoveSelectedPromptRight: Bool {
        guard let selectedPromptID = promptList.selectedPromptID,
              let index = promptList.prompts.firstIndex(where: { $0.id == selectedPromptID }) else {
            return false
        }
        return index < promptList.prompts.count - 1
    }

    private var tokenShelf: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Insert Column")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(columns) { column in
                        Button {
                            viewModel.insertToken(column.name)
                        } label: {
                            Text("{{\(column.name)}}")
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Insert \(column.name) token")
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.05))
    }

    private var content: some View {
        Group {
            if viewModel.prompt == nil {
                ContentUnavailableView(
                    "No Prompt",
                    systemImage: "text.badge.plus",
                    description: Text("Open a file and select a prompt to start editing.")
                )
            } else {
                editorContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Editor pane

    private var editorContent: some View {
        HSplitView {
            Group {
                if editorMode == .preview {
                    previewPane
                } else {
                    editorPane
                }
            }
            .frame(minWidth: 320)
            .layoutPriority(1)

            if showParameters, let prompt = viewModel.prompt {
                Divider()
                parametersInspector(prompt: prompt)
                    .frame(width: 250)
            }
        }
    }

    private var editorPane: some View {
        TextEditor(text: Binding(
                get: { viewModel.prompt?.template ?? "" },
                set: { viewModel.updateTemplate($0) }
            ))
        .font(.system(.body, design: .monospaced))
        .scrollContentBackground(.hidden)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Preview pane

    private var previewPane: some View {
        ScrollView {
            Text(viewModel.previewText.isEmpty ? "(template is empty)" : viewModel.previewText)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(viewModel.previewText.isEmpty ? .tertiary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .background(Color.secondary.opacity(0.05))
    }

    private func parametersInspector(prompt: Prompt) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Parameters")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            ParametersPanel(
                parameters: prompt.parameters,
                onChange: { viewModel.updateParameters($0) }
            )
        }
        .background(Color.secondary.opacity(0.04))
    }
}

// MARK: - Parameters panel

struct ParametersPanel: View {
    var parameters: LLMParameters
    var onChange: (LLMParameters) -> Void

    // Local string state for max tokens — Int? doesn't bind natively to TextField
    @State private var maxTokensText: String = ""

    var body: some View {
        Form {
            Section("Reasoning Effort") {
                HStack(spacing: 4) {
                    ForEach(ReasoningEffort.allCases, id: \.self) { level in
                        Button(level.rawValue.capitalized) {
                            toggleReasoningEffort(level)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.caption)
                        .tint(isReasoningEffortSelected(level) ? .accentColor : .secondary)
                    }
                }
                Text("Applies to o-series and GPT-5 models")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Section("Max Tokens") {
                HStack(spacing: 6) {
                    TextField("Unlimited", text: $maxTokensText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .font(.caption)
                        .onChange(of: maxTokensText) {
                            var updated = parameters
                            updated.maxTokens = maxTokensText.isEmpty ? nil : Int(maxTokensText)
                            onChange(updated)
                        }
                    Text("tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                maxTokensText = parameters.maxTokens.map(String.init) ?? ""
            }

            Section("Temperature") {
                VStack(alignment: .leading, spacing: 2) {
                    Slider(value: binding(\.temperature), in: 0...2, step: 0.1)
                    Text(String(format: "%.1f", parameters.temperature))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Section("Top-P") {
                VStack(alignment: .leading, spacing: 2) {
                    Slider(value: binding(\.topP), in: 0...1, step: 0.05)
                    Text(String(format: "%.2f", parameters.topP))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Section("Frequency Penalty") {
                VStack(alignment: .leading, spacing: 2) {
                    Slider(value: binding(\.frequencyPenalty), in: -2...2, step: 0.1)
                    Text(String(format: "%.1f", parameters.frequencyPenalty))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Section("Presence Penalty") {
                VStack(alignment: .leading, spacing: 2) {
                    Slider(value: binding(\.presencePenalty), in: -2...2, step: 0.1)
                    Text(String(format: "%.1f", parameters.presencePenalty))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 4)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<LLMParameters, T>) -> Binding<T> {
        Binding(
            get: { parameters[keyPath: keyPath] },
            set: { newValue in
                var updated = parameters
                updated[keyPath: keyPath] = newValue
                onChange(updated)
            }
        )
    }

    private func isReasoningEffortSelected(_ level: ReasoningEffort) -> Bool {
        parameters.reasoningEffort == level
    }

    private func toggleReasoningEffort(_ level: ReasoningEffort) {
        var updated = parameters
        updated.reasoningEffort = parameters.reasoningEffort == level ? nil : level
        onChange(updated)
    }
}
