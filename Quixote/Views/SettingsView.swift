import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    @State private var showKey = false
    @ObservedObject private var cache = ResponseCache.shared

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
                        if showKey {
                            TextField("sk-…", text: $viewModel.openAIKey)
                        } else {
                            SecureField("sk-…", text: $viewModel.openAIKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: viewModel.openAIKey) {
                        viewModel.keyValidationResult = nil
                    }

                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .help(showKey ? "Hide key" : "Show key")

                    Divider().frame(height: 20)

                    Button {
                        viewModel.validateKey()
                    } label: {
                        if viewModel.isValidatingKey {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Validate")
                        }
                    }
                    .disabled(viewModel.isValidatingKey)
                    .frame(width: 72)
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
            Label("Key saved to Keychain", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .invalid(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
}
