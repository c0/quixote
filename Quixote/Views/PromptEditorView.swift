import SwiftUI

struct PromptEditorView: View {
    private enum EditorMode: String, CaseIterable {
        case write
        case preview
    }

    @ObservedObject var viewModel: PromptEditorViewModel
    @ObservedObject var promptList: PromptListViewModel
    @ObservedObject var settings: SettingsViewModel
    let columns: [ColumnDef]
    @Binding var selectedModelIDs: Set<String>

    @State private var editorMode: EditorMode = .write
    @State private var showModelPicker = false

    private var selectedModels: [ModelConfig] {
        settings.availableModels.filter { selectedModelIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
                .padding(.horizontal, QuixoteSpacing.paneInset)
                .padding(.vertical, 14)

            QuixoteRowDivider()

            Group {
                if viewModel.prompt == nil {
                    ContentUnavailableView(
                        "No Prompt",
                        systemImage: "text.badge.plus",
                        description: Text("Open a file and select a prompt to start editing.")
                    )
                } else {
                    editorLayout
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.quixotePanelRaised)
    }

    private var tabStrip: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(promptList.prompts) { prompt in
                        HStack(spacing: 10) {
                            Button {
                                promptList.selectPrompt(prompt.id)
                            } label: {
                                Text(prompt.name)
                                    .font(.system(size: 14, weight: prompt.id == promptList.selectedPromptID ? .bold : .medium))
                                    .foregroundStyle(prompt.id == promptList.selectedPromptID ? Color.quixoteTextPrimary : Color.quixoteTextSecondary)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)

                            Button {
                                promptList.deletePrompt(id: prompt.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.quixoteTextSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(prompt.id == promptList.selectedPromptID ? Color.quixoteSelection : Color.clear)
                        )
                    }
                }
            }

            Button {
                promptList.addPrompt()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.quixoteTextSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var editorLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QuixoteSpacing.sectionGap) {
                modelSection
                variablesSection
                systemMessageSection
                promptSection
            }
            .padding(QuixoteSpacing.paneInset)
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuixoteSectionLabel(text: "Model")

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            showModelPicker = true
                        } label: {
                            HStack(spacing: 10) {
                                Text(modelSummaryTitle)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.quixoteTextPrimary)
                                Circle()
                                    .fill(Color.quixoteGreen)
                                    .frame(width: 10, height: 10)
                                    .shadow(color: Color.quixoteGreen.opacity(0.7), radius: 6)
                            }
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showModelPicker) {
                            ModelPickerPopover(
                                groupedModels: settings.groupedModels,
                                selectedIDs: selectedModelIDs,
                                onToggle: toggleModel,
                                onSelectAll: selectAllModels,
                                onDeselectAll: deselectAllModels
                            )
                        }

                        Text(modelSummaryDetail)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.quixoteGreen)
                    }

                    Spacer()

                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.quixoteTextSecondary)
                }

                if let prompt = viewModel.prompt {
                    PromptParametersCard(
                        parameters: prompt.parameters,
                        selectedModels: selectedModels,
                        onChange: { viewModel.updateParameters($0) }
                    )
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                    .fill(Color.quixoteCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                            .stroke(Color.quixoteDivider, lineWidth: 1)
                    )
            )
        }
    }

    private var variablesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuixoteSectionLabel(text: "Variables")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 10) {
                ForEach(columns) { column in
                    Button {
                        viewModel.insertToken(column.name)
                    } label: {
                        QuixoteChip(text: column.name, actionIcon: "xmark")
                    }
                    .buttonStyle(.plain)
                }

                QuixoteChip(text: "Add", actionIcon: nil, tint: .quixoteTextSecondary, fill: .quixotePanel)
            }
        }
    }

    private var systemMessageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuixoteSectionLabel(text: "System Message")
            editorCard(
                text: Binding(
                    get: { viewModel.prompt?.systemMessage ?? "" },
                    set: { viewModel.updateSystemMessage($0) }
                ),
                placeholder: "Describe desired model behavior (tone, tool usage, response style)"
            )
            .frame(height: 190)
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                QuixoteSectionLabel(text: "Prompt")
                Spacer()
                Picker("", selection: $editorMode) {
                    Text("Write").tag(EditorMode.write)
                    Text("Preview").tag(EditorMode.preview)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .colorScheme(.dark)
            }

            if editorMode == .preview {
                previewCard
                    .frame(minHeight: 280)
            } else {
                editorCard(
                    text: Binding(
                        get: { viewModel.prompt?.template ?? "" },
                        set: { viewModel.updateTemplate($0) }
                    ),
                    placeholder: "Summarized in 3 bullet points:\n{{body_html}}"
                )
                .frame(minHeight: 320)
            }
        }
    }

    private var previewCard: some View {
        ScrollView {
            Text(viewModel.previewText.isEmpty ? "(template is empty)" : viewModel.previewText)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(viewModel.previewText.isEmpty ? Color.quixoteTextMuted : Color.quixoteTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
        }
        .background(
            RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                .fill(Color.quixoteCard)
                .overlay(
                    RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                        .stroke(Color.quixoteDivider, lineWidth: 1)
                )
        )
    }

    private func editorCard(text: Binding<String>, placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                .fill(Color.quixoteCard)
                .overlay(
                    RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                        .stroke(Color.quixoteDivider, lineWidth: 1)
                )

            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color.quixoteTextPrimary)
                .padding(14)
                .background(Color.clear)

            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.quixoteTextMuted)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
    }

    private var modelSummaryTitle: String {
        if selectedModels.isEmpty { return "No model selected" }
        if selectedModels.count == 1 { return selectedModels[0].id }
        return "\(selectedModels.count) models selected"
    }

    private var modelSummaryDetail: String {
        guard let prompt = viewModel.prompt else { return "tokens: \(columns.count)" }
        return "temp: \(String(format: "%.2f", prompt.parameters.temperature))  top_p: \(String(format: "%.2f", prompt.parameters.topP))  tokens: \(prompt.parameters.maxTokens ?? 2048)"
    }

    private func toggleModel(_ id: String) {
        if selectedModelIDs.contains(id) {
            selectedModelIDs.remove(id)
        } else {
            selectedModelIDs.insert(id)
        }
    }

    private func selectAllModels(_ models: [ModelConfig]) {
        for model in models {
            selectedModelIDs.insert(model.id)
        }
    }

    private func deselectAllModels(_ models: [ModelConfig]) {
        for model in models {
            selectedModelIDs.remove(model.id)
        }
    }
}

private struct PromptParametersCard: View {
    var parameters: LLMParameters
    let selectedModels: [ModelConfig]
    var onChange: (LLMParameters) -> Void

    @State private var maxTokensText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                parameterMetric(title: "Temperature", value: String(format: "%.2f", parameters.temperature))
                parameterMetric(title: "Top P", value: String(format: "%.2f", parameters.topP))
                parameterMetric(title: "Max Tokens", value: parameters.maxTokens.map(String.init) ?? "auto")
            }

            if selectedModels.contains(where: { $0.supportsReasoningEffort }) {
                HStack(spacing: 8) {
                    ForEach(ReasoningEffort.allCases, id: \.self) { level in
                        Button(level.rawValue.capitalized) {
                            var updated = parameters
                            updated.reasoningEffort = parameters.reasoningEffort == level ? nil : level
                            onChange(updated)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(parameters.reasoningEffort == level ? Color.quixoteBlue : Color.quixoteSelection)
                        )
                        .foregroundStyle(Color.quixoteTextPrimary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                parameterSlider(title: "Temperature", value: parameters.temperature, range: 0...2, step: 0.1) {
                    var updated = parameters
                    updated.temperature = $0
                    onChange(updated)
                }
                parameterSlider(title: "Top P", value: parameters.topP, range: 0...1, step: 0.05) {
                    var updated = parameters
                    updated.topP = $0
                    onChange(updated)
                }
                parameterSlider(title: "Frequency", value: parameters.frequencyPenalty, range: -2...2, step: 0.1) {
                    var updated = parameters
                    updated.frequencyPenalty = $0
                    onChange(updated)
                }
                parameterSlider(title: "Presence", value: parameters.presencePenalty, range: -2...2, step: 0.1) {
                    var updated = parameters
                    updated.presencePenalty = $0
                    onChange(updated)
                }
            }

            HStack(spacing: 10) {
                Text("Max tokens")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.quixoteTextSecondary)

                TextField("2048", text: $maxTokensText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.quixotePanel)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.quixoteDivider, lineWidth: 1)
                            )
                    )
                    .frame(width: 90)
                    .onChange(of: maxTokensText) {
                        var updated = parameters
                        updated.maxTokens = maxTokensText.isEmpty ? nil : Int(maxTokensText)
                        onChange(updated)
                    }
            }
        }
        .onAppear {
            maxTokensText = parameters.maxTokens.map(String.init) ?? ""
        }
    }

    private func parameterMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Color.quixoteTextSecondary)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.quixoteTextPrimary)
        }
    }

    private func parameterSlider(
        title: String,
        value: Double,
        range: ClosedRange<Double>,
        step: Double,
        onUpdate: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color.quixoteTextSecondary)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextSecondary)
            }

            Slider(
                value: Binding(get: { value }, set: onUpdate),
                in: range,
                step: step
            )
            .tint(Color.quixoteBlue)
        }
    }
}
