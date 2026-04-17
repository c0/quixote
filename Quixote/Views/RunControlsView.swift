import SwiftUI

struct RunControlsView: View {
    @ObservedObject var processing: ProcessingViewModel
    @ObservedObject var settings: SettingsViewModel
    let selectedPrompt: Prompt?
    let prompts: [Prompt]
    let rows: [Row]
    let columns: [ColumnDef]
    let modelConfigs: [ResolvedFileModelConfig]

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
            && !modelConfigs.isEmpty
            && !processing.isActive
    }

    var body: some View {
        HStack(spacing: 14) {
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

                splitRunButton
            }
        }
    }

    private var runAction: () -> Void {
        {
            processing.startRun(
                prompts: promptsToRun,
                rows: rowsToProcess,
                columns: columns,
                modelConfigs: modelConfigs,
                apiKey: apiKey,
                concurrency: settings.concurrency,
                rateLimit: Double(settings.rateLimit),
                maxRetries: settings.maxRetries
            )
        }
    }

    private var splitRunButton: some View {
        let caretSegmentWidth: CGFloat = 48

        return HStack(spacing: 0) {
            Button(action: runAction) {
                Label("RUN", systemImage: "play")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.white)
                    .frame(minWidth: 92)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ZStack {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: caretSegmentWidth, height: 46)

                Menu {
                    Picker("Rows", selection: $rowLimit) {
                        Text("All rows").tag(RowLimit.all)
                        Text("First 10").tag(RowLimit.first(10))
                        Text("First 50").tag(RowLimit.first(50))
                        Text("First 100").tag(RowLimit.first(100))
                    }
                } label: {
                    Color.clear
                }
                .frame(width: caretSegmentWidth, height: 46)
                .frame(width: caretSegmentWidth, height: 46)
                .contentShape(Rectangle())
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .accessibilityLabel("Row limit")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                .fill(Color.quixoteBlue)
                .overlay(alignment: .center) {
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 1)
                            .padding(.vertical, 12)
                            .offset(x: -caretSegmentWidth)
                    }
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        }
        .disabled(!canRun)
        .opacity(canRun ? 1 : 0.5)
        .accessibilityElement(children: .contain)
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
