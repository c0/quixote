import SwiftUI

struct MainWindow: View {
    @StateObject private var workspace = WorkspaceViewModel()
    @StateObject private var dataPreview = DataPreviewViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(workspace: workspace)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            DataTableView(viewModel: dataPreview)
                .navigationTitle(workspace.selectedFile?.displayName ?? "Quixote")
                .navigationSubtitle(subtitleText)
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            loadSelectedFile()
        }
        .onChange(of: workspace.selectedFileID) {
            loadSelectedFile()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFilePicker)) { _ in
            workspace.openFilePicker()
        }
    }

    private var subtitleText: String {
        guard let file = workspace.selectedFile else { return "" }
        let table = workspace.parsedTable(for: file)
        guard !table.columns.isEmpty else { return "" }
        return "\(table.rows.count) rows · \(table.columns.count) columns"
    }

    private func loadSelectedFile() {
        guard let file = workspace.selectedFile else {
            dataPreview.clear()
            return
        }
        let table = workspace.parsedTable(for: file)
        dataPreview.load(table: table)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    workspace.addFile(url: url)
                }
            }
            handled = true
        }
        return handled
    }
}
