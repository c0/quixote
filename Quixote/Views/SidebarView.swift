import SwiftUI

struct SidebarView: View {
    @ObservedObject var workspace: WorkspaceViewModel
    @ObservedObject var pinnedPrompts: PinnedPromptsViewModel
    @Binding var selection: SidebarSelection?
    let onAddPin: () -> UUID?
    let onDuplicatePin: (UUID) -> UUID?
    let onDeletePin: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, QuixoteSpacing.shell)
                .padding(.top, 12)
                .padding(.bottom, 10)

            QuixoteRowDivider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    sectionHeader("DATA", action: workspace.openFilePicker, help: "Open a file (⌘O)")

                    ForEach(workspace.files) { file in
                        sidebarRow(for: file)
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    workspace.removeFile(file)
                                }
                            }
                    }

                    QuixoteRowDivider()
                        .padding(.vertical, 8)

                    sectionHeader("PROMPTS", action: addPinnedPrompt, help: "New pinned prompt")

                    if pinnedPrompts.prompts.isEmpty {
                        Text("No pinned prompts. Pin from any prompt tab to save it here.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.quixoteTextMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(pinnedPrompts.prompts) { prompt in
                            pinnedPromptRow(for: prompt)
                                .contextMenu {
                                    Button("Duplicate") {
                                        if let id = onDuplicatePin(prompt.id) {
                                            selection = .pinnedPrompt(id)
                                        }
                                    }
                                    Button("Delete", role: .destructive) {
                                        onDeletePin(prompt.id)
                                        if selection == .pinnedPrompt(prompt.id) {
                                            selection = workspace.selectedFileID.map(SidebarSelection.data)
                                        }
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.quixotePanel)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("SidebarLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: QuixoteSpacing.smallRadius, style: .continuous))

            Text("Quixote")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.quixoteTextPrimary)

            Spacer(minLength: 0)
        }
    }

    private func sectionHeader(_ title: String, action: @escaping () -> Void, help: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(2.2)
                .foregroundStyle(Color.quixoteTextMuted)
            Spacer(minLength: 0)
            Button {
                action()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.quixoteTextSecondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help(help)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 2)
    }

    private func addPinnedPrompt() {
        guard let id = onAddPin() else { return }
        selection = .pinnedPrompt(id)
    }

    private func sidebarRow(for file: WorkspaceFile) -> some View {
        Button {
            selection = .data(file.id)
            workspace.selectedFileID = file.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: iconName(for: file))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(file.isAvailable ? Color.quixoteTextSecondary : Color.quixoteOrange)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 3) {
                    Text(file.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(file.isAvailable ? Color.quixoteTextPrimary : Color.quixoteTextSecondary)
                        .lineLimit(1)

                    if let status = statusText(for: file) {
                        Text(status.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Color.quixoteTextMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
                    .background(
                RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                    .fill(isSelected(fileID: file.id) ? Color.quixoteSelection : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                            .stroke(isSelected(fileID: file.id) ? Color.quixoteDivider : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func pinnedPromptRow(for prompt: PinnedPrompt) -> some View {
        Button {
            selection = .pinnedPrompt(prompt.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.quixoteTextSecondary)
                    .frame(width: 16)

                Text(prompt.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.quixoteTextPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                    .fill(isSelected(promptID: prompt.id) ? Color.quixoteSelection : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                            .stroke(isSelected(promptID: prompt.id) ? Color.quixoteDivider : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func isSelected(fileID: UUID) -> Bool {
        selection == .data(fileID)
    }

    private func isSelected(promptID: UUID) -> Bool {
        selection == .pinnedPrompt(promptID)
    }

    private func iconName(for file: WorkspaceFile) -> String {
        if !file.isAvailable {
            switch file.restoreState {
            case .bookmarkMissing, .bookmarkResolutionFailed, .accessDenied:
                return "exclamationmark.triangle"
            case .missing:
                return "questionmark.folder"
            case .parseFailed:
                return "doc.badge.xmark"
            case .available:
                return "doc"
            }
        }

        switch file.fileType {
        case .csv: return "tablecells"
        case .json: return "curlybraces"
        case .xlsx: return "tablecells.badge.ellipsis"
        case .unknown: return "doc.text"
        }
    }

    private func statusText(for file: WorkspaceFile) -> String? {
        switch file.restoreState {
        case .available:
            return nil
        case .bookmarkMissing, .bookmarkResolutionFailed, .accessDenied:
            return "Access lost"
        case .missing:
            return "Missing"
        case .parseFailed:
            return "Unreadable"
        }
    }
}
