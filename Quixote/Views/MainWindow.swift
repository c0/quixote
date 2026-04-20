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
    @StateObject private var fileModelConfigs = FileModelConfigsViewModel()
    @State private var showFileChangedAlert = false

    var body: some View {
        HSplitView {
            SidebarView(workspace: workspace)
                .frame(minWidth: 220, idealWidth: 220, maxWidth: 240)

            PromptEditorView(
                viewModel: promptEditor,
                promptList: promptList,
                settings: settings,
                modelConfigs: fileModelConfigs,
                columns: dataPreview.columns
            )
            .frame(minWidth: 400, idealWidth: 440, maxWidth: 500)

            DataTableView(
                viewModel: dataPreview,
                results: resultsVM,
                statsVM: statsVM,
                processing: processing,
                settings: settings,
                selectedPromptID: promptList.selectedPromptID,
                datasetName: workspace.selectedFile?.displayName ?? "Quixote",
                datasetSubtitle: subtitleText.isEmpty ? "No dataset loaded" : subtitleText,
                selectedPrompt: promptList.selectedPrompt,
                prompts: promptList.prompts,
                rows: dataPreview.allRows,
                columns: dataPreview.columns,
                modelConfigs: resolvedModelConfigs,
                canExport: canExport,
                onExport: triggerExport,
                onRetry: { rowID, promptID, modelConfigID in
                    processing.retryResult(rowID: rowID, promptID: promptID, modelConfigID: modelConfigID)
                }
            )
            .frame(minWidth: 580, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.quixoteAppBackground)
        .preferredColorScheme(.dark)
        .frame(minWidth: 1240, minHeight: 760)
        .onAppear {
            promptEditor.onPromptUpdated = { [weak promptList] prompt in
                promptList?.updatePrompt(prompt)
            }
            workspace.onFileRemoved = { [weak promptList, weak processing] file in
                promptList?.removePrompts(for: file.id)
                processing?.clearPersistedCompletedResults(for: file.id)
                fileModelConfigs.removeConfigs(for: file.id)
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
        .onChange(of: settings.availableModels) {
            fileModelConfigs.ensureAvailableModelsAreValid(settings.availableModels)
            refreshDerivedViewModels()
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
        .onChange(of: processing.results) {
            refreshDerivedViewModels()
        }
        .onChange(of: processing.runState) {
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

    private var resolvedModelConfigs: [ResolvedFileModelConfig] {
        fileModelConfigs.resolvedConfigs(using: settings.availableModels)
    }

    private var canExport: Bool {
        workspace.selectedFile?.isAvailable == true && !dataPreview.columns.isEmpty
    }

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

    private func triggerExport() {
        guard let file = workspace.selectedFile else { return }
        let table = workspace.parsedTable(for: file)
        exportVM.export(
            table: table,
            results: processing.results,
            resultColumns: resultsVM.columns,
            showCosineSimilarity: settings.showCosineSimilarity,
            showRougeMetrics: settings.showRougeMetrics,
            suggestedName: file.displayName
        )
    }

    private func loadSelectedFile() {
        guard let file = workspace.selectedFile else {
            processing.setActiveFile(nil)
            dataPreview.clear()
            promptList.clear()
            promptEditor.clear()
            fileModelConfigs.clear()
            processing.clearDisplayedResults()
            refreshDerivedViewModels()
            return
        }
        processing.setActiveFile(file.id)
        guard file.isAvailable else {
            dataPreview.clear()
            promptList.clear()
            promptEditor.clear()
            fileModelConfigs.clear()
            processing.clearDisplayedResults()
            refreshDerivedViewModels()
            return
        }
        let table = workspace.parsedTable(for: file)
        dataPreview.load(table: table)
        promptList.load(fileID: file.id)
        let legacyModelIDs = Array(readLegacySelectedModelIDs())
        let legacyParameters = promptList.prompts.first?.parameters ?? LLMParameters()
        fileModelConfigs.load(
            fileID: file.id,
            availableModels: settings.availableModels,
            legacyModelIDs: legacyModelIDs,
            legacyParameters: legacyParameters
        )
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
            modelConfigs: resolvedModelConfigs
        )
        statsVM.update(
            results: processing.results,
            prompts: promptList.prompts,
            modelConfigs: resolvedModelConfigs,
            rows: dataPreview.allRows,
            runState: processing.runState,
            runStartedAt: processing.runStartedAt
        )
    }

    private func readLegacySelectedModelIDs() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: "quixote.selectedModels"),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        return ids
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
