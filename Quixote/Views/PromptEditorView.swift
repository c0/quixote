import AppKit
import SwiftUI

struct PromptEditorView: View {
    private enum EditorMode: String, CaseIterable {
        case write
        case preview
    }

    @ObservedObject var viewModel: PromptEditorViewModel
    @ObservedObject var promptList: PromptListViewModel
    @ObservedObject var settings: SettingsViewModel
    @ObservedObject var modelConfigs: FileModelConfigsViewModel
    let columns: [ColumnDef]

    @State private var editorMode: EditorMode = .write
    @State private var showAddModelPicker = false
    @State private var hiddenVariableColumnIDs: Set<UUID> = []

    private var resolvedModelConfigs: [ResolvedFileModelConfig] {
        modelConfigs.resolvedConfigs(using: settings.availableModels)
    }

    private var visibleVariableColumns: [ColumnDef] {
        columns.filter { !hiddenVariableColumnIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
                .padding(.horizontal, QuixoteSpacing.paneInset)
                .padding(.vertical, 10)

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
        .onChange(of: columns) { _, newColumns in
            hiddenVariableColumnIDs.formIntersection(Set(newColumns.map(\.id)))
            viewModel.updatePreviewColumns(visibleVariableColumns)
        }
        .onChange(of: hiddenVariableColumnIDs) { _, _ in
            viewModel.updatePreviewColumns(visibleVariableColumns)
        }
    }

    private var tabStrip: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(promptList.prompts) { prompt in
                        HStack(spacing: 8) {
                            Text(prompt.name)
                                .font(.system(size: 12, weight: prompt.id == promptList.selectedPromptID ? .bold : .medium))
                                .foregroundStyle(prompt.id == promptList.selectedPromptID ? Color.quixoteTextPrimary : Color.quixoteTextSecondary)
                                .lineLimit(1)

                            Button {
                                promptList.deletePrompt(id: prompt.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.quixoteTextSecondary)
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            promptList.selectPrompt(prompt.id)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                                .fill(prompt.id == promptList.selectedPromptID ? Color.quixoteSelection : Color.clear)
                        )
                    }
                }
            }

            Button {
                promptList.addPrompt()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
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
            .padding(.horizontal, QuixoteSpacing.paneInset)
            .padding(.vertical, 14)
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                QuixoteSectionLabel(text: "Model")
                Spacer()
                Button {
                    showAddModelPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.quixoteTextSecondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAddModelPicker) {
                    SingleModelPickerPopover(
                        groupedModels: settings.groupedModels,
                        selectedID: nil
                    ) { modelID in
                        modelConfigs.addModel(modelID: modelID, availableModels: settings.availableModels)
                        showAddModelPicker = false
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(resolvedModelConfigs) { config in
                    ModelConfigCard(
                        config: config,
                        groupedModels: settings.groupedModels,
                        canDelete: resolvedModelConfigs.count > 1,
                        onSelectModel: { modelID in
                            modelConfigs.updateModel(configID: config.id, modelID: modelID, availableModels: settings.availableModels)
                        },
                        onUpdateParameters: { parameters in
                            modelConfigs.updateParameters(configID: config.id, parameters: parameters, availableModels: settings.availableModels)
                        },
                        onDelete: {
                            modelConfigs.removeConfig(id: config.id, availableModels: settings.availableModels)
                        }
                    )
                }
            }
        }
    }

    private var variablesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuixoteSectionLabel(text: "Variables")

            QuixoteFlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(visibleVariableColumns) { column in
                    VariableTokenChip(
                        text: column.name,
                        onInsert: {
                            viewModel.insertToken(column.name)
                        },
                        onRemove: {
                            viewModel.removeToken(column.name)
                            hiddenVariableColumnIDs.insert(column.id)
                        }
                    )
                }

                QuixoteChip(text: "Add", actionIcon: nil, tint: .quixoteTextSecondary, fill: .quixotePanel)
            }
        }
    }

    private var systemMessageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuixoteSectionLabel(text: "System Message")
            editorCard(
                text: Binding(
                    get: { viewModel.prompt?.systemMessage ?? "" },
                    set: { viewModel.updateSystemMessage($0) }
                ),
                placeholder: "Describe desired model behavior (tone, tool usage, response style)"
            )
            .frame(height: 160)
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                QuixoteSectionLabel(text: "Prompt")
                Spacer()
                Picker("", selection: $editorMode) {
                    Text("Write").tag(EditorMode.write)
                    Text("Preview").tag(EditorMode.preview)
                }
                .pickerStyle(.segmented)
                .frame(width: 132)
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
                .frame(minHeight: 280)
            }
        }
    }

    private var previewCard: some View {
        ScrollView {
            Text(viewModel.previewText.isEmpty ? "(template is empty)" : viewModel.previewText)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(viewModel.previewText.isEmpty ? Color.quixoteTextMuted : Color.quixoteTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
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
                .padding(10)
                .background(Color.clear)

            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.quixoteTextMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct VariableTokenChip: View {
    private static let maxTextWidth: CGFloat = 220
    private static let removeWidth: CGFloat = 28

    let text: String
    let onInsert: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onInsert) {
                Text(text)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: Self.maxTextWidth, alignment: .leading)
                    .padding(.leading, 9)
                    .padding(.trailing, 6)
                    .frame(height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ZStack {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.quixoteTextSecondary)

                VariableRemoveHitTarget(action: onRemove)
                    .frame(width: Self.removeWidth, height: 28)
                    .accessibilityLabel("Remove variable from prompt")
            }
            .frame(width: Self.removeWidth, height: 28)
            .contentShape(Rectangle())
        }
        .background(
            RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                .fill(Color.quixoteSelection)
                .overlay(
                    RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                        .stroke(Color.quixoteDivider, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous))
    }
}

// Same full-rect hit-target workaround as the run caret: the visible x segment
// must own the entire right side so clicks there never fall through to insert.
private struct VariableRemoveHitTarget: NSViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.title = ""
        button.isBordered = false
        button.bezelStyle = .shadowlessSquare
        button.setButtonType(.momentaryChange)
        button.focusRingType = .none
        button.target = context.coordinator
        button.action = #selector(Coordinator.performAction(_:))
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        button.toolTip = "Remove variable from prompt"
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction(_ sender: NSButton) {
            action()
        }
    }
}

private struct QuixoteFlowLayout: Layout {
    var spacing: CGFloat = 10
    var rowSpacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = makeRows(maxWidth: maxWidth, subviews: subviews)
        return measuredSize(for: rows)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = makeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map(\.size.height).max() ?? 0

            for element in row {
                element.subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }

            y += rowHeight + rowSpacing
        }
    }

    private func makeRows(
        maxWidth: CGFloat,
        subviews: Subviews
    ) -> [[LayoutElement]] {
        let measured = subviews.map { subview in
            LayoutElement(subview: subview, size: subview.sizeThatFits(.unspecified))
        }

        guard maxWidth.isFinite else {
            return measured.isEmpty ? [] : [measured]
        }

        var rows: [[LayoutElement]] = []
        var currentRow: [LayoutElement] = []
        var currentWidth: CGFloat = 0

        for element in measured {
            let proposedWidth = currentRow.isEmpty
                ? element.size.width
                : currentWidth + spacing + element.size.width

            if !currentRow.isEmpty && proposedWidth > maxWidth {
                rows.append(currentRow)
                currentRow = [element]
                currentWidth = element.size.width
            } else {
                currentRow.append(element)
                currentWidth = proposedWidth
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    private func rowWidth(for row: [LayoutElement]) -> CGFloat {
        guard !row.isEmpty else { return 0 }
        var contentWidth: CGFloat = 0
        for element in row {
            contentWidth += element.size.width
        }
        let gapWidth = spacing * CGFloat(max(0, row.count - 1))
        return contentWidth + gapWidth
    }

    private func rowHeight(for row: [LayoutElement]) -> CGFloat {
        var tallest: CGFloat = 0
        for element in row {
            tallest = max(tallest, element.size.height)
        }
        return tallest
    }

    private func measuredSize(for rows: [[LayoutElement]]) -> CGSize {
        var width: CGFloat = 0
        var height: CGFloat = 0

        for index in rows.indices {
            let row = rows[index]
            width = max(width, rowWidth(for: row))
            height += rowHeight(for: row)
            if index < rows.count - 1 {
                height += rowSpacing
            }
        }

        return CGSize(width: width, height: height)
    }

    private struct LayoutElement {
        let subview: LayoutSubview
        let size: CGSize
    }
}

private struct ModelConfigCard: View {
    let config: ResolvedFileModelConfig
    let groupedModels: [(family: String, models: [ModelConfig])]
    let canDelete: Bool
    let onSelectModel: (String) -> Void
    let onUpdateParameters: (LLMParameters) -> Void
    let onDelete: () -> Void

    @State private var isExpanded = false
    @State private var showModelPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    showModelPicker = true
                } label: {
                    Text(config.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.quixoteTextPrimary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showModelPicker) {
                    SingleModelPickerPopover(
                        groupedModels: groupedModels,
                        selectedID: config.modelID,
                        onSelect: { modelID in
                            onSelectModel(modelID)
                            showModelPicker = false
                        }
                    )
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(isExpanded ? Color.quixoteTextPrimary : Color.quixoteTextSecondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(canDelete ? Color.quixoteTextSecondary : Color.quixoteTextMuted)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDelete)
                }
            }

            HStack(spacing: 14) {
                SummaryMetric(title: "Temp", value: Self.decimalString(config.parameters.temperature))
                SummaryMetric(title: "Top P", value: Self.decimalString(config.parameters.topP))
                SummaryMetric(title: "Max Tokens", value: config.parameters.maxTokens.map(String.init) ?? "Auto")
                if config.model.supportsReasoningEffort {
                    SummaryMetric(title: "Reasoning Level", value: config.parameters.reasoningEffort?.displayName ?? "Default")
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ParameterSliderRow(
                        title: "Temp",
                        value: config.parameters.temperature,
                        range: 0...2,
                        step: 0.1
                    ) { newValue in
                        var updated = config.parameters
                        updated.temperature = newValue
                        onUpdateParameters(updated)
                    }

                    ParameterSliderRow(
                        title: "Top P",
                        value: config.parameters.topP,
                        range: 0...1,
                        step: 0.05
                    ) { newValue in
                        var updated = config.parameters
                        updated.topP = newValue
                        onUpdateParameters(updated)
                    }

                    if !config.model.supportedReasoningLevels.isEmpty {
                        ReasoningLevelRow(
                            supportedLevels: config.model.supportedReasoningLevels,
                            selectedLevel: config.parameters.reasoningEffort
                        ) { level in
                            var updated = config.parameters
                            updated.reasoningEffort = level
                            onUpdateParameters(updated)
                        }
                    }

                    MaxTokensRow(value: config.parameters.maxTokens) { newValue in
                        var updated = config.parameters
                        updated.maxTokens = newValue
                        onUpdateParameters(updated)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                .fill(Color.quixoteCard)
                .overlay(
                    RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                        .stroke(Color.quixoteDivider, lineWidth: 1)
                )
        )
    }

    private static func decimalString(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color.quixoteTextSecondary)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.quixoteTextPrimary)
        }
    }
}

private struct ReasoningLevelRow: View {
    let supportedLevels: [ReasoningEffort]
    let selectedLevel: ReasoningEffort?
    let onSelect: (ReasoningEffort?) -> Void

    var body: some View {
        HStack {
            Text("Reasoning Level")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.quixoteTextSecondary)
            Spacer()
            Menu {
                Button("Default") { onSelect(nil) }
                ForEach(supportedLevels, id: \.self) { level in
                    Button(level.displayName) { onSelect(level) }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedLevel?.displayName ?? "Default")
                        .font(.system(size: 12, design: .monospaced))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color.quixoteTextPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                        .fill(Color.quixotePanel)
                        .overlay(
                            RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                                .stroke(Color.quixoteDivider, lineWidth: 1)
                        )
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
        }
    }
}

private struct MaxTokensRow: View {
    let value: Int?
    let onUpdate: (Int?) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text("Max Tokens")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.quixoteTextSecondary)

            Spacer()

            TextField("Auto", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .foregroundStyle(Color.quixoteTextPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(width: 96)
                .background(
                    RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                        .fill(Color.quixotePanel)
                        .overlay(
                            RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                                .stroke(Color.quixoteDivider, lineWidth: 1)
                        )
                )
                .onSubmit(commit)
                .onChange(of: isFocused) {
                    if !isFocused { commit() }
                }
        }
        .onAppear {
            text = value.map(String.init) ?? ""
        }
        .onChange(of: value) {
            if !isFocused {
                text = value.map(String.init) ?? ""
            }
        }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            text = ""
            onUpdate(nil)
            return
        }
        guard let parsed = Int(trimmed), parsed > 0 else {
            text = value.map(String.init) ?? ""
            return
        }
        text = String(parsed)
        onUpdate(parsed)
    }
}

private struct ParameterSliderRow: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onUpdate: (Double) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.quixoteTextSecondary)

                Spacer()

                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .focused($isFocused)
                    .foregroundStyle(Color.quixoteTextPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(width: 70)
                    .background(
                        RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                            .fill(Color.quixotePanel)
                            .overlay(
                                RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                                    .stroke(Color.quixoteDivider, lineWidth: 1)
                            )
                    )
                    .onSubmit(commit)
                    .onChange(of: isFocused) {
                        if !isFocused { commit() }
                    }
            }

            CompactValueSlider(value: value, range: range, step: step, onUpdate: onUpdate)
                .frame(height: 18)
        }
        .onAppear {
            text = formatted(value)
        }
        .onChange(of: value) {
            if !isFocused {
                text = formatted(value)
            }
        }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Double(trimmed) else {
            text = formatted(value)
            return
        }
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        let snapped = (clamped / step).rounded() * step
        text = formatted(snapped)
        onUpdate(snapped)
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

private struct CompactValueSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onUpdate: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width - 12, 1)
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let knobX = progress * width

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.quixotePanel)
                    .frame(height: 6)

                Capsule(style: .continuous)
                    .fill(Color.quixoteTextMuted.opacity(0.72))
                    .frame(width: knobX + 6, height: 6)

                Circle()
                    .fill(Color.quixoteTextPrimary)
                    .frame(width: 12, height: 12)
                    .offset(x: knobX)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let x = min(max(gesture.location.x - 6, 0), width)
                        let rawValue = range.lowerBound + Double(x / width) * (range.upperBound - range.lowerBound)
                        let snapped = (rawValue / step).rounded() * step
                        let clamped = min(max(snapped, range.lowerBound), range.upperBound)
                        onUpdate(clamped)
                    }
            )
        }
    }
}
