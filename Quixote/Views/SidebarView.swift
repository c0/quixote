import SwiftUI

struct SidebarView: View {
    @ObservedObject var workspace: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            Divider()

            List(workspace.files, selection: $workspace.selectedFileID) { file in
                HStack(spacing: 8) {
                    Image(systemName: iconName(for: file))
                        .foregroundStyle(file.isAvailable ? .primary : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.displayName)
                            .foregroundStyle(file.isAvailable ? .primary : .secondary)
                            .lineLimit(1)

                        if let status = statusText(for: file) {
                            Text(status)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                    .tag(file.id)
                    .contextMenu {
                        Button("Remove", role: .destructive) {
                            workspace.removeFile(file)
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button {
                    workspace.openFilePicker()
                } label: {
                    Label("Open File", systemImage: "plus")
                }
                .help("Open a file (⌘O)")
            }
        }
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image("SidebarLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text("Quixote")
                .font(.system(size: 16, weight: .semibold))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
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
        case .unknown: return "doc"
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
