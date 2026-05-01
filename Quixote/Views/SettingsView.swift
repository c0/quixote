import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var cache = ResponseCache.shared

    @FocusState private var isKeyFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                apiKeysSection
                processingSection
                dataSection
                statsSection
                analyticsSection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .frame(width: 420, height: 520)
        .background(Color.quixotePanel)
        .preferredColorScheme(.dark)
        .onChange(of: isKeyFieldFocused) {
            viewModel.updateKeyFieldFocus(isKeyFieldFocused)
        }
        .onDisappear {
            isKeyFieldFocused = false
            viewModel.discardUnsavedAPIKeyChanges()
        }
    }

    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("API Keys")

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    apiKeyField

                    Group {
                        if viewModel.showsEyeToggle {
                            Button {
                                viewModel.toggleKeyVisibility()
                            } label: {
                                Image(systemName: viewModel.isKeyVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(viewModel.isKeyVisible ? Color.quixoteTextPrimary : Color.quixoteTextSecondary)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(width: 24, height: 24)
                        }
                    }

                    Group {
                        if viewModel.saveButtonUsesPrimaryStyle {
                            Button("Save") {
                                _ = viewModel.saveKey()
                            }
                            .buttonStyle(QuixotePrimaryButtonStyle())
                        } else {
                            Button("Save") {
                                _ = viewModel.saveKey()
                            }
                            .buttonStyle(QuixoteSecondaryButtonStyle())
                        }
                    }
                    .disabled(!viewModel.canSaveAPIKey)
                    .opacity(viewModel.canSaveAPIKey ? 1 : 0.5)

                    Button {
                        viewModel.validateKey()
                    } label: {
                        Text("Test")
                    }
                    .buttonStyle(QuixoteSecondaryButtonStyle())
                    .disabled(!viewModel.canTestAPIKey)
                    .opacity(viewModel.canTestAPIKey ? 1 : 0.5)
                }

                if let statusLine = viewModel.statusLine {
                    HStack(spacing: 6) {
                        statusIcon(for: statusLine.kind)
                        Text(statusLine.text)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(statusColor(for: statusLine.kind))
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var processingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Processing")

            sectionCard {
                stepperRow(
                    title: "Concurrency",
                    value: "\(viewModel.concurrency)"
                ) {
                    Stepper(
                        "",
                        value: Binding(
                            get: { viewModel.concurrency },
                            set: { viewModel.saveConcurrency($0) }
                        ),
                        in: 1...10
                    )
                    .labelsHidden()
                    .controlSize(.small)
                }

                stepperRow(
                    title: "Rate limit",
                    value: "\(viewModel.rateLimit) req/s"
                ) {
                    Stepper(
                        "",
                        value: Binding(
                            get: { viewModel.rateLimit },
                            set: { viewModel.saveRateLimit($0) }
                        ),
                        in: 1...20
                    )
                    .labelsHidden()
                    .controlSize(.small)
                }

                stepperRow(
                    title: "Max retries",
                    value: "\(viewModel.maxRetries)"
                ) {
                    Stepper(
                        "",
                        value: Binding(
                            get: { viewModel.maxRetries },
                            set: { viewModel.saveMaxRetries($0) }
                        ),
                        in: 0...10
                    )
                    .labelsHidden()
                    .controlSize(.small)
                }
            }
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Data")

            sectionCard {
                settingsRow(title: "Response cache") {
                    HStack(spacing: 12) {
                        Text(cache.entryCount == 1 ? "1 entry" : "\(cache.entryCount) entries")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.quixoteTextSecondary)

                        Button("Clear") {
                            viewModel.clearCache()
                        }
                        .buttonStyle(QuixoteSecondaryButtonStyle())
                        .disabled(cache.entryCount == 0)
                        .opacity(cache.entryCount == 0 ? 0.5 : 1)
                    }
                }
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Stats")

            sectionCard {
                toggleRow(
                    title: "Show extrapolated projections",
                    isOn: Binding(
                        get: { viewModel.showExtrapolation },
                        set: { viewModel.saveShowExtrapolation($0) }
                    )
                )

                if viewModel.showExtrapolation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scale")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.quixoteTextSecondary)

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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Analytics")

            sectionCard {
                toggleRow(
                    title: "Show cosine similarity",
                    isOn: Binding(
                        get: { viewModel.showCosineSimilarity },
                        set: { viewModel.saveShowCosineSimilarity($0) }
                    )
                )

                toggleRow(
                    title: "Show ROUGE metrics",
                    isOn: Binding(
                        get: { viewModel.showRougeMetrics },
                        set: { viewModel.saveShowRougeMetrics($0) }
                    )
                )
            }
        }
    }

    private var apiKeyField: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                if !viewModel.apiKeyPlaceholder.isEmpty && viewModel.apiKeyDisplayText.isEmpty {
                    Text(viewModel.apiKeyPlaceholder)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color.quixoteTextMuted)
                        .allowsHitTesting(false)
                }

                if !viewModel.showsEditableTextField {
                    Text(viewModel.apiKeyDisplayText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(viewModel.displayTextColor)
                        .tracking(viewModel.usesMaskedLetterSpacing ? 1.3 : 0)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                }

                TextField("", text: Binding(
                    get: { viewModel.openAIKey },
                    set: { value in
                        viewModel.openAIKey = value
                        viewModel.markKeyFieldEdited()
                    }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(viewModel.editableTextColor)
                .focused($isKeyFieldFocused)
                .opacity(viewModel.showsEditableTextField ? 1 : 0.015)
            }

            inlineIndicator
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.quixoteSelection)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(viewModel.keyFieldBorderColor, lineWidth: 1.5)
        }
        .shadow(color: viewModel.keyFieldRingColor, radius: 0, x: 0, y: 0)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.clear)
                .shadow(color: viewModel.keyFieldRingColor, radius: 0, x: 0, y: 0)
        )
        .frame(minWidth: 0, maxWidth: .infinity)
        .onTapGesture {
            isKeyFieldFocused = true
        }
    }

    @ViewBuilder
    private var inlineIndicator: some View {
        switch viewModel.inlineIndicator {
        case .none:
            EmptyView()
        case .spinner:
            ProgressView()
                .controlSize(.small)
                .tint(Color.quixoteBlue)
        case .success:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.quixoteGreen)
        case .failure:
            Image(systemName: "xmark.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.quixoteRed)
        case .warning:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.quixoteOrange)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.quixoteTextPrimary)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.quixoteCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.quixoteDivider, lineWidth: 1)
                )
        )
    }

    private func settingsRow<Content: View>(
        title: String,
        @ViewBuilder trailing: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Color.quixoteTextPrimary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func stepperRow<Content: View>(
        title: String,
        value: String,
        @ViewBuilder control: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("\(title): \(value)")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.quixoteTextPrimary)

                Spacer()

                control()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            QuixoteRowDivider()
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            Toggle(isOn: isOn) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.quixoteTextPrimary)
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            QuixoteRowDivider()
        }
    }

    @ViewBuilder
    private func statusIcon(for kind: APIKeyStatusLine.Kind) -> some View {
        switch kind {
        case .success:
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.quixoteGreen)
        case .failure:
            Image(systemName: "xmark.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.quixoteRed)
        case .warning:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.quixoteOrange)
        case .neutral:
            EmptyView()
        }
    }

    private func statusColor(for kind: APIKeyStatusLine.Kind) -> Color {
        switch kind {
        case .success:
            return .quixoteGreen
        case .failure:
            return .quixoteRed
        case .warning:
            return .quixoteOrange
        case .neutral:
            return .quixoteTextSecondary
        }
    }
}
