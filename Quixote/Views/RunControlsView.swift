import AppKit
import SwiftUI

struct RunActionControls: View {
    @ObservedObject var processing: ProcessingViewModel
    @ObservedObject var settings: SettingsViewModel
    let selectedPrompt: Prompt?
    let prompts: [Prompt]
    let rows: [Row]
    let columns: [ColumnDef]
    let modelConfigs: [ResolvedFileModelConfig]
    let onOpenSettings: () -> Void

    @State private var rowLimit: RowLimit = .all
    @State private var runScope: RunScope = .selected

    private var selectedRunnablePrompt: Prompt? {
        guard let selectedPrompt,
              !selectedPrompt.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return selectedPrompt
    }

    private var rowsToProcess: [Row] {
        switch rowLimit {
        case .all:          return rows
        case .first(let n): return Array(rows.prefix(n))
        }
    }

    private var runnablePrompts: [Prompt] {
        prompts.filter { !$0.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var promptsToRun: [Prompt] {
        switch runScope {
        case .selected:
            guard let selectedRunnablePrompt else { return [] }
            return [selectedRunnablePrompt]
        case .all:
            return runnablePrompts
        }
    }

    private var hasRunnableInputs: Bool {
        settings.hasSavedAPIKey
            && !rowsToProcess.isEmpty
            && !modelConfigs.isEmpty
            && !processing.isActive
    }

    private var canRun: Bool {
        hasRunnableInputs && !promptsToRun.isEmpty
    }

    private var canRerunCurrent: Bool {
        hasRunnableInputs && selectedRunnablePrompt != nil
    }

    private var canRerunAll: Bool {
        hasRunnableInputs && !runnablePrompts.isEmpty
    }

    private var isRunMenuEnabled: Bool {
        canRun || canRerunCurrent || canRerunAll
    }

    var body: some View {
        HStack(spacing: 14) {
            if !settings.hasSavedAPIKey {
                Button(action: onOpenSettings) {
                    Label("Set API key in Settings", systemImage: "key.fill")
                        .font(.caption)
                        .foregroundStyle(Color.quixoteOrange)
                }
                .buttonStyle(.plain)
            }

            actionCluster
        }
    }

    @ViewBuilder
    private var actionCluster: some View {
        switch processing.runState {
        case .running:
            HStack(spacing: 6) {
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
            HStack(spacing: 6) {
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
            HStack(spacing: 6) {
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

    private func startRun(prompts: [Prompt], resetCache: Bool) {
            let apiKey: String
            do {
                apiKey = try settings.apiKeyForUserAction()
            } catch {
                settings.presentAPIKeyError(error.localizedDescription)
                onOpenSettings()
                return
            }

        if resetCache {
            resetCacheEntries(for: prompts)
        }

        processing.startRun(
            prompts: prompts,
            rows: rowsToProcess,
            columns: columns,
            modelConfigs: modelConfigs,
            apiKey: apiKey,
            concurrency: settings.concurrency,
            rateLimit: Double(settings.rateLimit),
            maxRetries: settings.maxRetries
        )
    }

    private func resetCacheEntries(for prompts: [Prompt]) {
        var keys = Set<String>()
        for prompt in prompts {
            for row in rowsToProcess {
                let expandedPrompt = InterpolationEngine.expand(
                    template: prompt.template,
                    row: row,
                    columns: columns
                )

                for modelConfig in modelConfigs {
                    keys.insert(
                        ResponseCache.cacheKey(
                            expandedPrompt: expandedPrompt,
                            systemMessage: prompt.systemMessage,
                            modelID: modelConfig.modelID,
                            params: modelConfig.parameters
                        )
                    )
                }
            }
        }
        ResponseCache.shared.removeEntries(for: keys)
    }

    private var runAction: () -> Void {
        { startRun(prompts: promptsToRun, resetCache: false) }
    }

    private var rerunCurrentAction: (() -> Void)? {
        guard let selectedRunnablePrompt else { return nil }
        return {
            startRun(prompts: [selectedRunnablePrompt], resetCache: true)
        }
    }

    private var rerunAllAction: (() -> Void)? {
        guard !runnablePrompts.isEmpty else { return nil }
        return {
            startRun(prompts: runnablePrompts, resetCache: true)
        }
    }

    private var splitRunButton: some View {
        let caretSegmentWidth: CGFloat = 34

        return HStack(spacing: 0) {
            Button(action: runAction) {
                Label(rowLimit.runButtonTitle, systemImage: "play")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(Color.white)
                    .frame(minWidth: 72)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRun)

            ZStack {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white)

                RowLimitMenuHitTarget(
                    selection: $rowLimit,
                    isEnabled: isRunMenuEnabled,
                    canRerunCurrent: canRerunCurrent,
                    canRerunAll: canRerunAll,
                    onRerunCurrent: rerunCurrentAction,
                    onRerunAll: rerunAllAction
                )
                    .frame(width: caretSegmentWidth, height: 32)
                    .accessibilityLabel("Run options")
            }
            .frame(width: caretSegmentWidth, height: 32)
            .contentShape(Rectangle())
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
                            .padding(.vertical, 8)
                            .offset(x: -caretSegmentWidth)
                    }
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        }
        .opacity(isRunMenuEnabled ? 1 : 0.5)
        .accessibilityElement(children: .contain)
    }
}

// SwiftUI Menu hit testing can collapse to the label's intrinsic content even
// when the visible segment is larger. Host an AppKit control when the whole
// painted rect must be clickable.
private struct RowLimitMenuHitTarget: NSViewRepresentable {
    @Binding var selection: RowLimit
    let isEnabled: Bool
    let canRerunCurrent: Bool
    let canRerunAll: Bool
    let onRerunCurrent: (() -> Void)?
    let onRerunAll: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selection: $selection,
            onRerunCurrent: onRerunCurrent,
            onRerunAll: onRerunAll
        )
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.title = ""
        button.isBordered = false
        button.bezelStyle = .shadowlessSquare
        button.setButtonType(.momentaryChange)
        button.focusRingType = .none
        button.target = context.coordinator
        button.action = #selector(Coordinator.showMenu(_:))
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.selection = $selection
        context.coordinator.onRerunCurrent = onRerunCurrent
        context.coordinator.onRerunAll = onRerunAll
        context.coordinator.canRerunCurrent = canRerunCurrent
        context.coordinator.canRerunAll = canRerunAll
        button.isEnabled = isEnabled
        button.toolTip = "Run options"
    }

    final class Coordinator: NSObject {
        var selection: Binding<RowLimit>
        var canRerunCurrent = false
        var canRerunAll = false
        var onRerunCurrent: (() -> Void)?
        var onRerunAll: (() -> Void)?

        init(
            selection: Binding<RowLimit>,
            onRerunCurrent: (() -> Void)?,
            onRerunAll: (() -> Void)?
        ) {
            self.selection = selection
            self.onRerunCurrent = onRerunCurrent
            self.onRerunAll = onRerunAll
        }

        @objc func showMenu(_ sender: NSButton) {
            let menu = NSMenu()
            addItem("All rows", tag: 0, to: menu)
            addItem("First 10", tag: 10, to: menu)
            addItem("First 100", tag: 100, to: menu)
            addItem("First 1000", tag: 1000, to: menu)
            menu.addItem(.separator())
            addActionItem("Rerun", action: #selector(rerunCurrent), enabled: canRerunCurrent, to: menu)
            addActionItem("Rerun all prompts", action: #selector(rerunAll), enabled: canRerunAll, to: menu)

            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY - 2), in: sender)
        }

        private func addItem(_ title: String, tag: Int, to menu: NSMenu) {
            let item = NSMenuItem(title: title, action: #selector(selectRowLimit(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            item.state = selection.wrappedValue == rowLimit(for: tag) ? .on : .off
            menu.addItem(item)
        }

        private func addActionItem(_ title: String, action: Selector, enabled: Bool, to menu: NSMenu) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.isEnabled = enabled
            menu.addItem(item)
        }

        @objc private func selectRowLimit(_ sender: NSMenuItem) {
            selection.wrappedValue = rowLimit(for: sender.tag)
        }

        @objc private func rerunCurrent() {
            onRerunCurrent?()
        }

        @objc private func rerunAll() {
            onRerunAll?()
        }

        private func rowLimit(for tag: Int) -> RowLimit {
            switch tag {
            case 10, 100, 1000:
                return .first(tag)
            default:
                return .all
            }
        }
    }
}

enum RowLimit: Hashable {
    case all
    case first(Int)

    var runButtonTitle: String {
        switch self {
        case .all:
            return "RUN"
        case .first(let count):
            return "RUN \(count)"
        }
    }
}

enum RunScope: Hashable {
    case selected
    case all
}
