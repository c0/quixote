import SwiftUI

struct MainWindow: View {
    @StateObject private var workspace = WorkspaceViewModel()
    @StateObject private var dataPreview = DataPreviewViewModel()
    @StateObject private var promptList = PromptListViewModel()
    @StateObject private var promptEditor = PromptEditorViewModel()
    @StateObject private var processing = ProcessingViewModel()
    @StateObject private var resultsVM = ResultsViewModel()
    @StateObject private var statsVM = StatsViewModel()
    @StateObject private var exportVM = ExportViewModel()
    @StateObject private var settings = SettingsViewModel()

    @State private var selectedModels: [ModelConfig] = []
    @State private var showFileChangedAlert = false

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
                        selectedPromptID: promptList.selectedPromptID,
                        onRetry: { rowID, promptID, modelID in
                            processing.retryResult(rowID: rowID, promptID: promptID, modelID: modelID)
                        }
                    )
                    .frame(minHeight: 250, idealHeight: 320)

                    promptWorkspace
                        .frame(minHeight: 260, idealHeight: 340)
                        .layoutPriority(1)
                }

                bottomControls
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
            promptEditor.onPromptUpdated = { [weak promptList] prompt in
                promptList?.updatePrompt(prompt)
            }
            workspace.onFileRemoved = { [weak promptList, weak processing] file in
                promptList?.removePrompts(for: file.id)
                processing?.clearPersistedCompletedResults(for: file.id)
            }
            for file in workspace.changedFiles {
                processing.clearPersistedCompletedResults(for: file.id)
            }
            loadSelectedFile()
            processing.restoreIfNeeded()
            if !workspace.changedFiles.isEmpty {
                showFileChangedAlert = true
            }
        }
        .onChange(of: workspace.selectedFileID) {
            processing.cancel()
            resultsVM.clear()
            statsVM.clear()
            loadSelectedFile()
        }
        .onChange(of: promptList.selectedPromptID) {
            syncPromptEditor()
        }
        .onChange(of: promptList.prompts) {
            syncPromptEditor()
            refreshDerivedViewModels()
        }
        .onChange(of: selectedModels) {
            refreshDerivedViewModels()
        }
        .onChange(of: processing.results) {
            refreshDerivedViewModels()
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
        .alert("Files Changed", isPresented: $showFileChangedAlert) {
            Button("Re-run") {
                processing.clearResults()
                workspace.refreshContentHashes()
                workspace.acknowledgeChanges()
            }
            Button("Dismiss", role: .cancel) {
                workspace.acknowledgeChanges()
            }
        } message: {
            let names = workspace.changedFiles.map(\.displayName).joined(separator: ", ")
            Text("\(names) changed since last run. Previous results have been cleared.")
        }
    }

    // MARK: - Export

    private var promptWorkspace: some View {
        PromptEditorView(
            viewModel: promptEditor,
            promptList: promptList,
            columns: dataPreview.columns
        )
    }

    private var bottomControls: some View {
        VStack(spacing: 0) {
            Divider()

            StatsPanelView(
                statsVM: statsVM,
                selectedPromptID: promptList.selectedPromptID,
                showExtrapolation: settings.showExtrapolation,
                extrapolationScale: settings.extrapolationScale
            )

            if !statsVM.modelStats.isEmpty {
                Divider()
            }

            RunControlsView(
                processing: processing,
                settings: settings,
                selectedPrompt: promptList.selectedPrompt,
                prompts: promptList.prompts,
                rows: dataPreview.allRows,
                columns: dataPreview.columns,
                onModelChanged: { selectedModels = $0 }
            )
        }
    }

    private var canExport: Bool {
        workspace.selectedFile?.isAvailable == true && !dataPreview.columns.isEmpty
    }

    private func triggerExport() {
        guard let file = workspace.selectedFile else { return }
        let table = workspace.parsedTable(for: file)
        exportVM.export(
            table: table,
            results: processing.results,
            resultColumns: resultsVM.columns,
            suggestedName: file.displayName
        )
    }

    // MARK: - Helpers

    private var subtitleText: String {
        guard let file = workspace.selectedFile else { return "" }
        guard file.isAvailable else {
            switch file.restoreState {
            case .bookmarkMissing, .bookmarkResolutionFailed, .accessDenied:
                return "Access could not be restored"
            case .missing:
                return "File unavailable"
            case .parseFailed:
                return "File could not be read"
            case .available:
                return ""
            }
        }
        let table = workspace.parsedTable(for: file)
        guard !table.columns.isEmpty else { return "" }
        return "\(table.rows.count) rows · \(table.columns.count) columns"
    }

    private func loadSelectedFile() {
        guard let file = workspace.selectedFile else {
            processing.setActiveFile(nil)
            dataPreview.clear()
            promptList.clear()
            promptEditor.clear()
            processing.clearDisplayedResults()
            refreshDerivedViewModels()
            return
        }
        processing.setActiveFile(file.id)
        guard file.isAvailable else {
            dataPreview.clear()
            promptList.clear()
            promptEditor.clear()
            processing.clearDisplayedResults()
            refreshDerivedViewModels()
            return
        }
        let table = workspace.parsedTable(for: file)
        dataPreview.load(table: table)
        promptList.load(fileID: file.id)
        processing.loadPersistedCompletedResults(for: file.id)
        syncPromptEditor()
        refreshDerivedViewModels()
    }

    private func syncPromptEditor() {
        promptEditor.load(prompt: promptList.selectedPrompt, table: workspace.selectedFile.map { workspace.parsedTable(for: $0) } ?? .empty)
    }

    private func refreshDerivedViewModels() {
        resultsVM.update(
            results: processing.results,
            prompts: promptList.prompts,
            models: selectedModels
        )
        statsVM.update(
            results: processing.results,
            prompts: promptList.prompts,
            models: selectedModels,
            totalRows: dataPreview.allRows.count
        )
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
