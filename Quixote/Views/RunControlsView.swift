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
        let caretSegmentWidth: CGFloat = 34

        return HStack(spacing: 0) {
            Button(action: runAction) {
                Label("RUN", systemImage: "play")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(Color.white)
                    .frame(minWidth: 72)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ZStack {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white)

                RowLimitMenuHitTarget(selection: $rowLimit, isEnabled: canRun)
                    .frame(width: caretSegmentWidth, height: 32)
                    .accessibilityLabel("Row limit")
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
        .disabled(!canRun)
        .opacity(canRun ? 1 : 0.5)
        .accessibilityElement(children: .contain)
    }
}

// SwiftUI Menu hit testing can collapse to the label's intrinsic content even
// when the visible segment is larger. Host an AppKit control when the whole
// painted rect must be clickable.
private struct RowLimitMenuHitTarget: NSViewRepresentable {
    @Binding var selection: RowLimit
    let isEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
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
        button.isEnabled = isEnabled
        button.toolTip = "Row limit"
    }

    final class Coordinator: NSObject {
        var selection: Binding<RowLimit>

        init(selection: Binding<RowLimit>) {
            self.selection = selection
        }

        @objc func showMenu(_ sender: NSButton) {
            let menu = NSMenu()
            addItem("All rows", tag: 0, to: menu)
            addItem("First 10", tag: 10, to: menu)
            addItem("First 50", tag: 50, to: menu)
            addItem("First 100", tag: 100, to: menu)

            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY - 2), in: sender)
        }

        private func addItem(_ title: String, tag: Int, to menu: NSMenu) {
            let item = NSMenuItem(title: title, action: #selector(selectRowLimit(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            item.state = selection.wrappedValue == rowLimit(for: tag) ? .on : .off
            menu.addItem(item)
        }

        @objc private func selectRowLimit(_ sender: NSMenuItem) {
            selection.wrappedValue = rowLimit(for: sender.tag)
        }

        private func rowLimit(for tag: Int) -> RowLimit {
            switch tag {
            case 10, 50, 100:
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
}

enum RunScope: Hashable {
    case selected
    case all
}
