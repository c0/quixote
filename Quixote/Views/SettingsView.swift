import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    @State private var isKeyVisible = false
    @ObservedObject private var cache = ResponseCache.shared

    private var maskedKeyPreview: String {
        let key = viewModel.openAIKey
        let visiblePrefix = 6
        let visibleSuffix = 4

        guard key.count >= visiblePrefix + visibleSuffix + 1 else {
            return String(repeating: "•", count: key.count)
        }

        let maskCount = key.count - visiblePrefix - visibleSuffix
        return "\(key.prefix(visiblePrefix))\(String(repeating: "•", count: maskCount))\(key.suffix(visibleSuffix))"
    }

    private var keyBinding: Binding<String> {
        Binding(
            get: { viewModel.openAIKey },
            set: { newValue in
                viewModel.openAIKey = newValue
                viewModel.markKeyFieldEdited()
            }
        )
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 420, height: 460)
    }

    // MARK: - General tab

    private var generalTab: some View {
        Form {
            // API Keys
            Section("API Keys") {
                HStack(spacing: 6) {
                    Group {
                        if isKeyVisible {
                            TextField(text: keyBinding, prompt: Text("sk-...")) {
                                EmptyView()
                            }
                        } else {
                            SecureField(text: keyBinding, prompt: Text("sk-...")) {
                                EmptyView()
                            }
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .frame(minWidth: 180, maxWidth: .infinity)

                    Button {
                        isKeyVisible.toggle()
                    } label: {
                        Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help(isKeyVisible ? "Hide sensitive data" : "Show full key")

                    Divider().frame(height: 20)

                    Button("Save") {
                        viewModel.saveKey()
                    }
                    .disabled(viewModel.isValidatingKey)
                    .frame(width: 54)

                    Button {
                        viewModel.validateKey()
                    } label: {
                        if viewModel.isValidatingKey {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Test")
                        }
                    }
                    .disabled(viewModel.isValidatingKey)
                    .frame(width: 72)
                    .help("Test this API key against OpenAI")
                }

                if !viewModel.openAIKey.isEmpty && !isKeyVisible {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Partial Preview")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(maskedKeyPreview)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .textSelection(.enabled)
                    }
                }

                validationFeedback
            }

            // Processing
            Section("Processing") {
                Stepper(
                    "Concurrency: \(viewModel.concurrency)",
                    value: Binding(
                        get: { viewModel.concurrency },
                        set: { viewModel.saveConcurrency($0) }
                    ),
                    in: 1...10
                )

                Stepper(
                    "Rate limit: \(viewModel.rateLimit) req/s",
                    value: Binding(
                        get: { viewModel.rateLimit },
                        set: { viewModel.saveRateLimit($0) }
                    ),
                    in: 1...20
                )

                Stepper(
                    "Max retries: \(viewModel.maxRetries)",
                    value: Binding(
                        get: { viewModel.maxRetries },
                        set: { viewModel.saveMaxRetries($0) }
                    ),
                    in: 0...10
                )
            }

            Section("Data") {
                HStack {
                    Text("Response cache")
                    Spacer()
                    Text(cache.entryCount == 1 ? "1 entry" : "\(cache.entryCount) entries")
                        .foregroundStyle(.secondary)
                    Button("Clear") {
                        viewModel.clearCache()
                    }
                    .disabled(cache.entryCount == 0)
                }
            }

            Section("Stats") {
                Toggle(
                    "Show extrapolated projections",
                    isOn: Binding(
                        get: { viewModel.showExtrapolation },
                        set: { viewModel.saveShowExtrapolation($0) }
                    )
                )

                if viewModel.showExtrapolation {
                    Picker(
                        "Scale",
                        selection: Binding(
                            get: { viewModel.extrapolationScale },
                            set: { viewModel.saveExtrapolationScale($0) }
                        )
                    ) {
                        ForEach(ExtrapolationScale.allCases, id: \.self) { scale in
                            Text(scale.displayName).tag(scale)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section("Analytics") {
                Toggle(
                    "Show cosine similarity",
                    isOn: Binding(
                        get: { viewModel.showCosineSimilarity },
                        set: { viewModel.saveShowCosineSimilarity($0) }
                    )
                )

                Toggle(
                    "Show ROUGE metrics",
                    isOn: Binding(
                        get: { viewModel.showRougeMetrics },
                        set: { viewModel.saveShowRougeMetrics($0) }
                    )
                )
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var validationFeedback: some View {
        switch viewModel.keyValidationResult {
        case .none:
            EmptyView()
        case .valid:
            Label("API Key valid", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .invalid(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
}
