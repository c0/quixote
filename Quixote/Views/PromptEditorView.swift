import SwiftUI

struct PromptEditorView: View {
    @ObservedObject var viewModel: PromptEditorViewModel
    let columns: [ColumnDef]

    @State private var showPreview = false
    @State private var showParameters = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if showPreview {
                previewPane
            } else {
                editorPane
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("Prompt")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            // Column token chips
            if !columns.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(columns) { column in
                            Button {
                                viewModel.insertToken(column.name)
                            } label: {
                                Text("{{\(column.name)}}")
                                    .font(.system(.caption2, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .help("Insert \(column.name) token")
                        }
                    }
                }
                .frame(maxWidth: 360)
            }

            Divider().frame(height: 16)

            Toggle(isOn: $showPreview) {
                Image(systemName: "eye")
            }
            .toggleStyle(.button)
            .help("Preview interpolated output (uses first row)")

            Toggle(isOn: $showParameters) {
                Image(systemName: "slider.horizontal.3")
            }
            .toggleStyle(.button)
            .help("LLM parameters")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Editor pane

    private var editorPane: some View {
        HStack(spacing: 0) {
            TextEditor(text: Binding(
                get: { viewModel.prompt?.template ?? "" },
                set: { viewModel.updateTemplate($0) }
            ))
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showParameters, let prompt = viewModel.prompt {
                Divider()
                ParametersPanel(
                    parameters: prompt.parameters,
                    onChange: { viewModel.updateParameters($0) }
                )
                .frame(width: 220)
            }
        }
    }

    // MARK: - Preview pane

    private var previewPane: some View {
        ScrollView {
            Text(viewModel.previewText.isEmpty ? "(template is empty)" : viewModel.previewText)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(viewModel.previewText.isEmpty ? .tertiary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .background(Color.secondary.opacity(0.04))
    }
}

// MARK: - Parameters panel

struct ParametersPanel: View {
    var parameters: LLMParameters
    var onChange: (LLMParameters) -> Void

    var body: some View {
        Form {
            Section("Temperature") {
                VStack(alignment: .leading, spacing: 2) {
                    Slider(value: binding(\.temperature), in: 0...2, step: 0.1)
                    Text(String(format: "%.1f", parameters.temperature))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Section("Top-P") {
                VStack(alignment: .leading, spacing: 2) {
                    Slider(value: binding(\.topP), in: 0...1, step: 0.05)
                    Text(String(format: "%.2f", parameters.topP))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Section("Frequency Penalty") {
                VStack(alignment: .leading, spacing: 2) {
                    Slider(value: binding(\.frequencyPenalty), in: -2...2, step: 0.1)
                    Text(String(format: "%.1f", parameters.frequencyPenalty))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Section("Presence Penalty") {
                VStack(alignment: .leading, spacing: 2) {
                    Slider(value: binding(\.presencePenalty), in: -2...2, step: 0.1)
                    Text(String(format: "%.1f", parameters.presencePenalty))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .padding(.vertical, 4)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<LLMParameters, T>) -> Binding<T> {
        Binding(
            get: { parameters[keyPath: keyPath] },
            set: { newValue in
                var updated = parameters
                updated[keyPath: keyPath] = newValue
                onChange(updated)
            }
        )
    }
}
