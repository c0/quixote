import SwiftUI

struct MainWindow: View {
    @StateObject private var workspace = WorkspaceViewModel()
    @StateObject private var dataPreview = DataPreviewViewModel()
    @StateObject private var promptEditor = PromptEditorViewModel()
    @StateObject private var processing = ProcessingViewModel()
    @StateObject private var resultsVM = ResultsViewModel()
    @StateObject private var statsVM = StatsViewModel()
    @StateObject private var exportVM = ExportViewModel()
    @StateObject private var settings = SettingsViewModel()

    @State private var selectedModels: [ModelConfig] = []

    var body: some View {
        NavigationSplitView {
            SidebarView(workspace: workspace)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            VStack(spacing: 0) {
                VSplitView {
                    DataTableView(
                        viewModel: dataPreview,
                        results: resultsVM,
                        onRetry: { rowID, modelID in
                            processing.retryResult(rowID: rowID, modelID: modelID)
                        }
                    )
                        .frame(minHeight: 200)

                    PromptEditorView(
                        viewModel: promptEditor,
                        columns: dataPreview.columns
                    )
                    .frame(minHeight: 120, idealHeight: 200)
                }

                Divider()

                // Stats panel (visible when results exist)
                StatsPanelView(statsVM: statsVM)

                Divider()

                RunControlsView(
                    processing: processing,
                    settings: settings,
                    prompt: promptEditor.prompt,
                    rows: dataPreview.allRows,
                    columns: dataPreview.columns,
                    onModelChanged: { selectedModels = $0 }
                )
            }
            .navigationTitle(workspace.selectedFile?.displayName ?? "Quixote")
            .navigationSubtitle(subtitleText)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        triggerExport()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!canExport)
                    .help("Save Results… (⌘S)")
                }
            }
        }
        .frame(minWidth: 720, minHeight: 560)
        .onAppear {
            workspace.onFileRemoved = { [weak promptEditor] file in
                promptEditor?.removePrompt(for: file.id)
            }
            loadSelectedFile()
        }
        .onChange(of: workspace.selectedFileID) {
            processing.cancel()
            resultsVM.clear()
            statsVM.clear()
            loadSelectedFile()
        }
        .onChange(of: processing.results) {
            resultsVM.update(
                results: processing.results,
                prompt: promptEditor.prompt,
                models: selectedModels
            )
            statsVM.update(
                results: processing.results,
                prompt: promptEditor.prompt,
                models: selectedModels,
                totalRows: dataPreview.allRows.count
            )
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFilePicker)) { _ in
            workspace.openFilePicker()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportResults)) { _ in
            triggerExport()
        }
    }

    // MARK: - Export

    private var canExport: Bool {
        workspace.selectedFile != nil && !dataPreview.columns.isEmpty
    }

    private func triggerExport() {
        guard let file = workspace.selectedFile else { return }
        let table = workspace.parsedTable(for: file)
        exportVM.export(
            table: table,
            results: processing.results,
            resultColumns: resultsVM.columns,
            prompt: promptEditor.prompt,
            models: selectedModels,
            suggestedName: file.displayName
        )
    }

    // MARK: - Helpers

    private var subtitleText: String {
        guard let file = workspace.selectedFile else { return "" }
        let table = workspace.parsedTable(for: file)
        guard !table.columns.isEmpty else { return "" }
        return "\(table.rows.count) rows · \(table.columns.count) columns"
    }

    private func loadSelectedFile() {
        guard let file = workspace.selectedFile else {
            dataPreview.clear()
            promptEditor.clear()
            return
        }
        let table = workspace.parsedTable(for: file)
        dataPreview.load(table: table)
        promptEditor.load(fileID: file.id, table: table)
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
