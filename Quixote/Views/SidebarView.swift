import SwiftUI

struct SidebarView: View {
    @ObservedObject var workspace: WorkspaceViewModel

    var body: some View {
        List(workspace.files, selection: $workspace.selectedFileID) { file in
            Label(file.displayName, systemImage: iconName(for: file.fileType))
                .tag(file.id)
                .contextMenu {
                    Button("Remove", role: .destructive) {
                        workspace.removeFile(file)
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

    private func iconName(for type: FileType) -> String {
        switch type {
        case .csv: return "tablecells"
        case .json: return "curlybraces"
        case .xlsx: return "tablecells.badge.ellipsis"
        case .unknown: return "doc"
        }
    }
}
