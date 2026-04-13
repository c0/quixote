import SwiftUI

struct RunControlsView: View {
    @ObservedObject var processing: ProcessingViewModel
    @ObservedObject var settings: SettingsViewModel
    let selectedPrompt: Prompt?
    let prompts: [Prompt]
    let rows: [Row]
    let columns: [ColumnDef]
    var onModelChanged: (([ModelConfig]) -> Void)? = nil

    @AppStorage("quixote.selectedModels") private var selectedModelIDsData: Data = Data()
    @State private var showModelPicker = false
    @State private var rowLimit: RowLimit = .all
    @State private var runScope: RunScope = .selected

    // MARK: - Selected models

    private var selectedModelIDs: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: selectedModelIDsData)) ?? ["gpt-4o-mini"]
        }
        nonmutating set {
            selectedModelIDsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    private var selectedModels: [ModelConfig] {
        let ids = selectedModelIDs
        return settings.availableModels.filter { ids.contains($0.id) }
    }

    private var rowsToProcess: [Row] {
        switch rowLimit {
        case .all:          return rows
        case .first(let n): return Array(rows.prefix(n))
        }
    }

    private var apiKey: String {
        settings.openAIKey.trimmingCharacters(in: .whitespaces)
    }

    private var runnablePrompts: [Prompt] {
        prompts.filter { !$0.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var promptsToRun: [Prompt] {
        switch runScope {
        case .selected:
            guard let selectedPrompt,
                  !selectedPrompt.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return []
            }
            return [selectedPrompt]
        case .all:
            return runnablePrompts
        }
    }

    private var canRun: Bool {
        !apiKey.isEmpty
            && !promptsToRun.isEmpty
            && !rows.isEmpty
            && !selectedModels.isEmpty
            && !processing.isActive
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 10) {
            // Model picker button
            modelPickerButton

            Divider().frame(height: 16)

            if prompts.count > 1 {
                Picker("", selection: $runScope) {
                    Text("Selected").tag(RunScope.selected)
                    Text("All").tag(RunScope.all)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

                Divider().frame(height: 16)
            }

            // Row limit
            Picker("", selection: $rowLimit) {
                Text("All rows").tag(RowLimit.all)
                Text("First 10").tag(RowLimit.first(10))
                Text("First 50").tag(RowLimit.first(50))
                Text("First 100").tag(RowLimit.first(100))
            }
            .frame(width: 100)
            .font(.caption)

            Divider().frame(height: 16)

            Text(batchSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider().frame(height: 16)

            // Progress
            progressSection

            Spacer()

            // API key hint when missing
            if apiKey.isEmpty {
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Set API key in Settings", systemImage: "key.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }

            // Run / Pause / Resume / Cancel
            switch processing.runState {
            case .running:
                HStack(spacing: 6) {
                    Button("Pause") {
                        processing.pause()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Cancel", role: .destructive) {
                        processing.cancel()
                    }
                    .font(.caption)
                }
            case .paused:
                HStack(spacing: 6) {
                    Button("Resume") {
                        processing.resume()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Cancel", role: .destructive) {
                        processing.cancel()
                    }
                    .font(.caption)
                }
            default:
                HStack(spacing: 6) {
                    if !processing.isActive && processing.hasFailedResults {
                        Button("Retry Failed") {
                            processing.retryFailed(
                                concurrency: settings.concurrency,
                                rateLimit: Double(settings.rateLimit)
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Button("Run") {
                        processing.startRun(
                            prompts: promptsToRun,
                            rows: rowsToProcess,
                            columns: columns,
                            models: selectedModels,
                            apiKey: apiKey,
                            concurrency: settings.concurrency,
                            rateLimit: Double(settings.rateLimit),
                            maxRetries: settings.maxRetries
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!canRun)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
        .onChange(of: selectedModelIDs) {
            onModelChanged?(selectedModels)
        }
        .onAppear {
            onModelChanged?(selectedModels)
        }
    }

    // MARK: - Model picker button

    @ViewBuilder
    private var modelPickerButton: some View {
        let models = selectedModels
        Button {
            showModelPicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                if models.isEmpty {
                    Text("No model")
                        .foregroundStyle(.orange)
                } else if models.count == 1 {
                    Text(models[0].displayName)
                } else {
                    Text("\(models.count) models")
                }
            }
            .font(.caption)
        }
        .buttonStyle(.plain)
        .frame(width: 130)
        .popover(isPresented: $showModelPicker) {
            ModelPickerPopover(
                groupedModels: settings.groupedModels,
                selectedIDs: selectedModelIDs,
                onToggle: { id in
                    var ids = selectedModelIDs
                    if ids.contains(id) {
                        ids.remove(id)
                    } else {
                        ids.insert(id)
                    }
                    selectedModelIDs = ids
                },
                onSelectAll: { familyModels in
                    var ids = selectedModelIDs
                    for m in familyModels { ids.insert(m.id) }
                    selectedModelIDs = ids
                },
                onDeselectAll: { familyModels in
                    var ids = selectedModelIDs
                    for m in familyModels { ids.remove(m.id) }
                    selectedModelIDs = ids
                }
            )
        }
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
        switch processing.runState {
        case .idle:
            EmptyView()
        case .running(let done, let total):
            HStack(spacing: 6) {
                ProgressView(value: Double(done), total: Double(total))
                    .frame(width: 80)
                Text("\(done)/\(total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .paused(let done, let total):
            HStack(spacing: 6) {
                ProgressView(value: Double(done), total: Double(total))
                    .frame(width: 80)
                Image(systemName: "pause.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("\(done)/\(total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .completed(let total):
            Label("\(total) done", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    private var batchSummary: String {
        let batchCount = promptsToRun.count * rowsToProcess.count * selectedModels.count
        return "\(batchCount) jobs"
    }
}

// MARK: - Model Picker Popover

private struct ModelPickerPopover: View {
    let groupedModels: [(family: String, models: [ModelConfig])]
    let selectedIDs: Set<String>
    let onToggle: (String) -> Void
    let onSelectAll: ([ModelConfig]) -> Void
    let onDeselectAll: ([ModelConfig]) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(groupedModels, id: \.family) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        // Family header with select/deselect all
                        HStack {
                            Text(group.family)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("All") { onSelectAll(group.models) }
                                .buttonStyle(.plain)
                                .font(.caption2)
                            Button("None") { onDeselectAll(group.models) }
                                .buttonStyle(.plain)
                                .font(.caption2)
                        }

                        ForEach(group.models) { model in
                            Toggle(model.displayName, isOn: toggleBinding(for: model.id))
                                .font(.caption)
                                .toggleStyle(.checkbox)
                        }
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 240, height: 300)
    }

    private func toggleBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(id) },
            set: { _ in onToggle(id) }
        )
    }
}

// MARK: - RowLimit

enum RowLimit: Hashable {
    case all
    case first(Int)
}

enum RunScope: Hashable {
    case selected
    case all
}
