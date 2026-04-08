import SwiftUI

// Persists API key to UserDefaults for CP-3. TODO AO-5: move to Keychain.
private let kAPIKey = "quixote.openai.apiKey"
private let kSelectedModel = "quixote.selectedModel"

struct RunControlsView: View {
    @ObservedObject var processing: ProcessingViewModel
    let prompt: Prompt?
    let rows: [Row]
    let columns: [ColumnDef]

    @AppStorage(kAPIKey) private var apiKey: String = ""
    @AppStorage(kSelectedModel) private var selectedModelID: String = "gpt-4o-mini"

    @State private var rowLimit: RowLimit = .all
    @State private var showAPIKey = false

    private var selectedModel: ModelConfig {
        ModelConfig.builtIn.first { $0.id == selectedModelID } ?? ModelConfig.builtIn[1]
    }

    private var rowsToProcess: [Row] {
        switch rowLimit {
        case .all:      return rows
        case .first(let n): return Array(rows.prefix(n))
        }
    }

    private var canRun: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
            && !(prompt?.template.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
            && !rows.isEmpty
            && !processing.isRunning
    }

    var body: some View {
        HStack(spacing: 10) {
            // API Key
            Group {
                if showAPIKey {
                    TextField("OpenAI API key", text: $apiKey)
                } else {
                    SecureField("OpenAI API key", text: $apiKey)
                }
            }
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 200)
            .font(.caption)

            Button {
                showAPIKey.toggle()
            } label: {
                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(showAPIKey ? "Hide key" : "Show key")

            Divider().frame(height: 16)

            // Model picker
            Picker("", selection: $selectedModelID) {
                ForEach(ModelConfig.builtIn) { model in
                    Text(model.displayName).tag(model.id)
                }
            }
            .frame(width: 130)
            .font(.caption)

            Divider().frame(height: 16)

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

            // Progress
            progressSection

            Spacer()

            // Run / Cancel
            if processing.isRunning {
                Button("Cancel", role: .destructive) {
                    processing.cancel()
                }
                .font(.caption)
            } else {
                Button("Run") {
                    guard let p = prompt else { return }
                    processing.startRun(
                        prompt: p,
                        rows: rowsToProcess,
                        columns: columns,
                        model: selectedModel,
                        apiKey: apiKey.trimmingCharacters(in: .whitespaces)
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canRun)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }

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
}

// MARK: - RowLimit

enum RowLimit: Hashable {
    case all
    case first(Int)
}
