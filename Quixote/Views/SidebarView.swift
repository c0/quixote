import SwiftUI

struct SidebarView: View {
    @ObservedObject var workspace: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            Divider()

            List(workspace.files, selection: $workspace.selectedFileID) { file in
                Label(file.displayName, systemImage: iconName(for: file.fileType))
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

    private func iconName(for type: FileType) -> String {
        switch type {
        case .csv: return "tablecells"
        case .json: return "curlybraces"
        case .xlsx: return "tablecells.badge.ellipsis"
        case .unknown: return "doc"
        }
    }
}
