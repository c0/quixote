import SwiftUI

struct PinnedPromptEditorView: View {
    let prompt: PinnedPrompt
    @ObservedObject var pinnedPrompts: PinnedPromptsViewModel
    @ObservedObject var workspace: WorkspaceViewModel
    let columnsForFile: (WorkspaceFile) -> [ColumnDef]
    let onRun: (PinnedPrompt, UUID) -> Void
    let onDuplicate: (UUID) -> Void
    let onDelete: (UUID) -> Void

    @State private var localName = ""
    @State private var localSystem = ""
    @State private var localTemplate = ""
    @State private var showRunPopover = false

    private var requiredVariables: [String] {
        InterpolationEngine.tokens(systemMessage: localSystem, template: localTemplate)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            QuixoteRowDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: QuixoteSpacing.sectionGap) {
                    editorSection(
                        title: "System Message",
                        text: $localSystem,
                        placeholder: "Describe desired model behavior (tone, tool usage, response style)",
                        minHeight: 120
                    )

                    editorSection(
                        title: "Prompt",
                        text: $localTemplate,
                        placeholder: "Summarize in 3 bullet points:\n{{column_name}}",
                        minHeight: 180
                    )

                    requiredVariablesSection
                }
                .padding(.horizontal, QuixoteSpacing.paneInset)
                .padding(.vertical, 14)
            }
        }
        .background(Color.quixotePanelRaised)
        .onAppear(perform: syncLocalState)
        .onChange(of: prompt) { _, _ in syncLocalState() }
        .onChange(of: localName) { _, _ in saveNow() }
        .onChange(of: localSystem) { _, _ in saveNow() }
        .onChange(of: localTemplate) { _, _ in saveNow() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "pin.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.quixoteTextPrimary)

            TextField("", text: $localName)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.quixoteTextPrimary)
                .onSubmit(saveNow)

            Spacer(minLength: 0)

            Button {
                showRunPopover = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("RUN ON...")
                }
            }
            .buttonStyle(QuixoteSecondaryButtonStyle())
            .popover(isPresented: $showRunPopover) {
                runPopover
            }

            iconButton("doc.on.doc", help: "Duplicate") {
                saveNow()
                onDuplicate(prompt.id)
            }

            iconButton("trash", help: "Delete") {
                onDelete(prompt.id)
            }
        }
        .padding(.horizontal, QuixoteSpacing.paneInset)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
    }

    private var requiredVariablesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuixoteSectionLabel(text: "Required Variables")

            if requiredVariables.isEmpty {
                Text("None - prompt is plain text. Add {{column_name}} tokens to interpolate row values.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextMuted)
            } else {
                QuixoteFlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(requiredVariables, id: \.self) { variable in
                        QuixoteChip(text: variable)
                    }
                }
            }
        }
    }

    private var runPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("APPLY TO DATASET")
                .font(.system(size: 10, weight: .bold))
                .tracking(2.2)
                .foregroundStyle(Color.quixoteTextMuted)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            let availableFiles = workspace.files.filter(\.isAvailable)
            if availableFiles.isEmpty {
                Text("No datasets open. Open a file from the DATA section first.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.quixoteTextMuted)
                    .padding(14)
            } else {
                ForEach(availableFiles) { file in
                    runPopoverRow(file)
                }
            }

            if !requiredVariables.isEmpty {
                QuixoteRowDivider()
                Text("Will check for: \(requiredVariables.joined(separator: ", "))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextMuted)
                    .padding(12)
            }
        }
        .frame(width: 300)
        .background(Color.quixotePanelRaised)
    }

    private func runPopoverRow(_ file: WorkspaceFile) -> some View {
        let missing = InterpolationEngine.missingTokens(in: requiredVariables, columns: columnsForFile(file))
        return Button {
            guard missing.isEmpty else { return }
            saveNow()
            showRunPopover = false
            onRun(currentPrompt(), file.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "tablecells")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(missing.isEmpty ? Color.quixoteTextSecondary : Color.quixoteOrange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(file.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.quixoteTextPrimary)
                        .lineLimit(1)
                    if !missing.isEmpty {
                        Text("Missing: \(missing.joined(separator: ", "))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.quixoteOrange)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.quixoteTextSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!missing.isEmpty)
    }

    private func editorSection(title: String, text: Binding<String>, placeholder: String, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            QuixoteSectionLabel(text: title)
            editorCard(text: text, placeholder: placeholder)
                .frame(minHeight: minHeight)
        }
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

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.quixoteTextSecondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func syncLocalState() {
        localName = prompt.name
        localSystem = prompt.systemMessage
        localTemplate = prompt.template
    }

    private func saveNow() {
        pinnedPrompts.update(currentPrompt())
    }

    private func currentPrompt() -> PinnedPrompt {
        var updated = prompt
        updated.name = localName
        updated.systemMessage = localSystem
        updated.template = localTemplate
        return updated
    }
}

struct PinnedPromptEmptyPane: View {
    let prompt: PinnedPrompt

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.quixoteCard)
                Image(systemName: "pin.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.quixoteTextSecondary)
            }
            .frame(width: 64, height: 64)

            Text(prompt.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.quixoteTextPrimary)

            Text("Pinned prompts are model-agnostic templates. Use Run on... to apply this prompt to a dataset and pick models there.")
                .font(.system(size: 13))
                .foregroundStyle(Color.quixoteTextMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            Spacer()

            HStack(spacing: 10) {
                Text("NO MODEL")
                Text("NO VARIABLES BOUND")
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(Color.quixoteTextMuted)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.quixoteAppBackground)
    }
}
