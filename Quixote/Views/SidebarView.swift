import SwiftUI

struct SidebarView: View {
    @ObservedObject var workspace: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, QuixoteSpacing.shell)
                .padding(.top, 12)
                .padding(.bottom, 10)

            QuixoteRowDivider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(workspace.files) { file in
                        sidebarRow(for: file)
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    workspace.removeFile(file)
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

            Button {
                workspace.openFilePicker()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.quixoteTextSecondary)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
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
                    .fill(file.id == workspace.selectedFileID ? Color.quixoteSelection : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
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
