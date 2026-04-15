import SwiftUI

struct RunControlsView: View {
    @ObservedObject var processing: ProcessingViewModel
    @ObservedObject var settings: SettingsViewModel
    let selectedPrompt: Prompt?
    let prompts: [Prompt]
    let rows: [Row]
    let columns: [ColumnDef]
    let selectedModels: [ModelConfig]

    @State private var rowLimit: RowLimit = .all
    @State private var runScope: RunScope = .selected

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

    var body: some View {
        HStack(spacing: 14) {
            statusCluster

            QuixotePaneDivider()
                .frame(height: 28)

            if prompts.count > 1 {
                Picker("", selection: $runScope) {
                    Text("Selected").tag(RunScope.selected)
                    Text("All").tag(RunScope.all)
                }
                .pickerStyle(.segmented)
                .frame(width: 156)
                .colorScheme(.dark)
            }

            Picker("", selection: $rowLimit) {
                Text("All rows").tag(RowLimit.all)
                Text("First 10").tag(RowLimit.first(10))
                Text("First 50").tag(RowLimit.first(50))
                Text("First 100").tag(RowLimit.first(100))
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Color.quixoteTextPrimary)

            Text(batchSummary)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.quixoteTextSecondary)

            Spacer(minLength: 12)

            if apiKey.isEmpty {
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Set API key in Settings", systemImage: "key.fill")
                        .font(.caption)
                        .foregroundStyle(Color.quixoteOrange)
                }
                .buttonStyle(.plain)
            }

            actionCluster
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.quixotePanel)
        .overlay(alignment: .top) {
            QuixoteRowDivider()
        }
    }

    private var statusCluster: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedModelsLabel)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.quixoteTextPrimary)

            progressSection
        }
    }

    @ViewBuilder
    private var actionCluster: some View {
        switch processing.runState {
        case .running:
            HStack(spacing: 8) {
                Button("PAUSE") {
                    processing.pause()
                }
                .buttonStyle(QuixoteSecondaryButtonStyle())

                Button("CANCEL", role: .destructive) {
                    processing.cancel()
                }
                .buttonStyle(QuixoteSecondaryButtonStyle())
            }
        case .paused:
            HStack(spacing: 8) {
                Button("RESUME") {
                    processing.resume()
                }
                .buttonStyle(QuixotePrimaryButtonStyle())

                Button("CANCEL", role: .destructive) {
                    processing.cancel()
                }
                .buttonStyle(QuixoteSecondaryButtonStyle())
            }
        default:
            HStack(spacing: 8) {
                if !processing.isActive && processing.hasFailedResults {
                    Button("RETRY FAILED") {
                        processing.retryFailed(
                            concurrency: settings.concurrency,
                            rateLimit: Double(settings.rateLimit)
                        )
                    }
                    .buttonStyle(QuixoteSecondaryButtonStyle())
                }

                Button {
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
                } label: {
                    Label("RUN", systemImage: "play")
                }
                .buttonStyle(QuixotePrimaryButtonStyle())
                .disabled(!canRun)
                .opacity(canRun ? 1 : 0.5)
            }
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        switch processing.runState {
        case .idle:
            Text("idle")
                .font(.caption)
                .foregroundStyle(Color.quixoteTextSecondary)
        case .running(let done, let total):
            HStack(spacing: 8) {
                ProgressView(value: Double(done), total: Double(total))
                    .frame(width: 96)
                    .tint(Color.quixoteBlue)
                Text("\(done)/\(total)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextSecondary)
            }
        case .paused(let done, let total):
            HStack(spacing: 8) {
                ProgressView(value: Double(done), total: Double(total))
                    .frame(width: 96)
                    .tint(Color.quixoteOrange)
                Image(systemName: "pause.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.quixoteOrange)
                Text("\(done)/\(total)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextSecondary)
            }
        case .completed(let total):
            Label("\(total) done", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.quixoteGreen)
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(Color.quixoteRed)
                .lineLimit(1)
        }
    }

    private var selectedModelsLabel: String {
        if selectedModels.isEmpty { return "no model selected" }
        if selectedModels.count == 1 { return selectedModels[0].displayName.lowercased() }
        return "\(selectedModels.count) models selected"
    }

    private var batchSummary: String {
        let batchCount = promptsToRun.count * rowsToProcess.count * selectedModels.count
        return "\(batchCount) jobs"
    }
}

enum RowLimit: Hashable {
    case all
    case first(Int)
}

enum RunScope: Hashable {
    case selected
    case all
}
