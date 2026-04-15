import SwiftUI

struct SidebarView: View {
    @ObservedObject var workspace: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, QuixoteSpacing.shell)
                .padding(.top, 18)
                .padding(.bottom, 14)

            QuixoteRowDivider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(workspace.files) { file in
                        sidebarRow(for: file)
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    workspace.removeFile(file)
                                }
                            }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.quixotePanel)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("SidebarLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text("Quixote")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.quixoteTextPrimary)

            Spacer(minLength: 0)

            Button {
                workspace.openFilePicker()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.quixoteTextSecondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.quixotePanelRaised)
                    )
            }
            .buttonStyle(.plain)
            .help("Open a file (⌘O)")
        }
    }

    private func sidebarRow(for file: WorkspaceFile) -> some View {
        Button {
            workspace.selectedFileID = file.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconName(for: file))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(file.isAvailable ? Color.quixoteTextSecondary : Color.quixoteOrange)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 3) {
                    Text(file.displayName)
                        .font(.system(size: 13, weight: .semibold))
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(file.id == workspace.selectedFileID ? Color.quixoteSelection : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(file.id == workspace.selectedFileID ? Color.quixoteDivider : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
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
