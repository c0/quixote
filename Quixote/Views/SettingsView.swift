import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var cache = ResponseCache.shared

    @FocusState private var focusedProviderKeyID: String?
    @State private var manualModelDrafts: [String: String] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                providersSection
                processingSection
                dataSection
                statsSection
                analyticsSection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .frame(width: 560, height: 680)
        .background(Color.quixotePanel)
        .preferredColorScheme(.dark)
        .onDisappear {
            focusedProviderKeyID = nil
            viewModel.discardUnsavedAPIKeyChanges()
        }
    }

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Providers")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.providerProfiles) { profile in
                    providerCard(profile)
                }
            }
        }
    }

    private func providerCard(_ profile: ProviderProfile) -> some View {
        let status = viewModel.providerStatusLines[profile.id]
        let isRefreshing = viewModel.refreshingProviderIDs.contains(profile.id)
        let keyDraft = Binding<String>(
            get: { viewModel.providerAPIKeyDrafts[profile.id] ?? "" },
            set: { viewModel.providerAPIKeyDrafts[profile.id] = $0 }
        )
        let manualDraft = Binding<String>(
            get: { manualModelDrafts[profile.id] ?? "" },
            set: { manualModelDrafts[profile.id] = $0 }
        )

        return sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.displayName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.quixoteTextPrimary)
                        Text(profile.kind.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.quixoteTextSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { profile.isEnabled },
                        set: { value in
                            var updated = profile
                            updated.isEnabled = value
                            viewModel.saveProvider(updated)
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Base URL")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.quixoteTextSecondary)

                    TextField("", text: Binding(
                        get: { profile.baseURL },
                        set: { value in
                            var updated = profile
                            updated.baseURL = value
                            viewModel.saveProvider(updated)
                        }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.quixoteSelection)
                    )
                }

                if profile.requiresAPIKey {
                    providerAPIKeySection(profile: profile, keyDraft: keyDraft)
                }

                HStack(spacing: 8) {
                    if !profile.requiresAPIKey {
                        Button("Test") {
                            viewModel.testProvider(profileID: profile.id)
                        }
                        .buttonStyle(QuixoteSecondaryButtonStyle())
                        .disabled(isRefreshing)
                    }

                    Button("Refresh Models") {
                        viewModel.refreshModels(for: profile.id)
                    }
                    .buttonStyle(QuixoteSecondaryButtonStyle())
                    .disabled(isRefreshing)

                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.quixoteBlue)
                    }

                    Spacer()

                    Text("\(profile.availableModelIDs.count) models")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.quixoteTextSecondary)
                }

                if profile.kind == .customOpenAICompatible {
                    Toggle(isOn: Binding(
                        get: { profile.requiresAPIKey },
                        set: { value in
                            var updated = profile
                            updated.requiresAPIKey = value
                            viewModel.saveProvider(updated)
                        }
                    )) {
                        Text("Requires API key")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.quixoteTextSecondary)
                    }
                    .toggleStyle(.checkbox)
                }

                if profile.kind != .openAI {
                    HStack(spacing: 8) {
                        TextField("Add model ID", text: manualDraft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.quixoteTextPrimary)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.quixoteSelection)
                            )
                            .onSubmit {
                                viewModel.addManualModel(profileID: profile.id, modelID: manualModelDrafts[profile.id] ?? "")
                                manualModelDrafts[profile.id] = ""
                            }

                        Button("Add") {
                            viewModel.addManualModel(profileID: profile.id, modelID: manualModelDrafts[profile.id] ?? "")
                            manualModelDrafts[profile.id] = ""
                        }
                        .buttonStyle(QuixoteSecondaryButtonStyle())
                    }

                    if !profile.manualModels.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(profile.manualModels, id: \.self) { modelID in
                                    Button {
                                        viewModel.removeManualModel(profileID: profile.id, modelID: modelID)
                                    } label: {
                                        HStack(spacing: 5) {
                                            Text(modelID)
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                .lineLimit(1)
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .bold))
                                        }
                                        .foregroundStyle(Color.quixoteTextSecondary)
                                        .padding(.horizontal, 8)
                                        .frame(height: 24)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(Color.quixoteSelection)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if let status, !profile.requiresAPIKey {
                    HStack(spacing: 6) {
                        statusIcon(for: status.kind)
                        Text(status.text)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(statusColor(for: status.kind))
                            .lineLimit(2)
                    }
                }
            }
            .padding(14)
        }
    }

    private func providerAPIKeySection(profile: ProviderProfile, keyDraft: Binding<String>) -> some View {
        let isFocused = focusedProviderKeyID == profile.id
        let state = viewModel.providerAPIKeyState(for: profile, isFocused: isFocused)
        let status = viewModel.providerAPIKeyStatusLine(for: profile)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                apiKeyInputField(
                    state: state,
                    text: Binding(
                        get: { keyDraft.wrappedValue },
                        set: { value in
                            keyDraft.wrappedValue = value
                            viewModel.markProviderAPIKeyEdited(profileID: profile.id)
                        }
                    ),
                    displayText: apiKeyDisplayText(
                        state: state,
                        draft: keyDraft.wrappedValue,
                        revealedText: viewModel.providerAPIKeyDisplayText(for: profile)
                    ),
                    focusID: profile.id,
                    focus: { focusedProviderKeyID = profile.id }
                )

                if providerShowsEyeToggle(profile: profile) {
                    Button {
                        viewModel.toggleProviderAPIKeyVisibility(profile: profile)
                    } label: {
                        Image(systemName: viewModel.visibleProviderAPIKeyIDs.contains(profile.id) ? "eye" : "eye.slash")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.visibleProviderAPIKeyIDs.contains(profile.id) ? Color.quixoteTextPrimary : Color.quixoteTextSecondary)
                    .help(viewModel.visibleProviderAPIKeyIDs.contains(profile.id) ? "Hide API key" : "Show API key")
                } else {
                    Color.clear.frame(width: 26, height: 18)
                }

                if viewModel.canSaveProviderAPIKey(profileID: profile.id) {
                    Button("Save") {
                        focusedProviderKeyID = nil
                        viewModel.saveProviderAPIKey(profileID: profile.id)
                    }
                    .buttonStyle(QuixotePrimaryButtonStyle())
                } else {
                    Button("Save") {
                        viewModel.saveProviderAPIKey(profileID: profile.id)
                    }
                    .buttonStyle(QuixoteSecondaryButtonStyle())
                    .disabled(true)
                    .opacity(0.55)
                }

                Button("Test") {
                    focusedProviderKeyID = nil
                    viewModel.testProvider(profileID: profile.id)
                }
                .buttonStyle(QuixoteSecondaryButtonStyle())
                .disabled(!viewModel.canTestProviderAPIKey(profile: profile) || isFocused)
                .opacity((!viewModel.canTestProviderAPIKey(profile: profile) || isFocused) ? 0.55 : 1)
            }

            if let status {
                HStack(spacing: 6) {
                    statusIcon(for: status.kind)
                    Text(status.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(statusColor(for: status.kind))
                        .lineLimit(2)
                }
                .padding(.horizontal, 2)
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
                        in: 1...100
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

    private func apiKeyInputField(
        state: APIKeyUIState,
        text: Binding<String>,
        displayText: String,
        focusID: String,
        focus: @escaping () -> Void
    ) -> some View {
        let draft = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let showEditableField = apiKeyShowsEditableTextField(state: state, draft: draft)

        return ZStack(alignment: .leading) {
            if apiKeyPlaceholder(for: state) != nil && draft.isEmpty {
                Text(apiKeyPlaceholder(for: state) ?? "")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextMuted)
                    .allowsHitTesting(false)
            }

            if !showEditableField {
                Text(displayText)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.quixoteTextSecondary)
                    .tracking(apiKeyUsesMaskedLetterSpacing(state) ? 1.3 : 0)
                    .lineLimit(1)
                    .allowsHitTesting(false)
            }

            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(draft.isEmpty ? Color.quixoteTextMuted : Color.quixoteTextSecondary)
                .focused($focusedProviderKeyID, equals: focusID)
                .opacity(showEditableField ? 1 : 0.015)

            HStack {
                Spacer()
                apiKeyInlineIndicator(for: state)
            }
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.quixoteSelection)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(apiKeyFieldBorderColor(for: state), lineWidth: 1.5)
        }
        .shadow(color: apiKeyFieldRingColor(for: state), radius: 0, x: 0, y: 0)
        .frame(minWidth: 0, maxWidth: .infinity)
        .onTapGesture(perform: focus)
    }

    private func apiKeyDisplayText(state: APIKeyUIState, draft: String, revealedText: String) -> String {
        switch state {
        case .blank, .focused:
            return ""
        case .typing:
            return draft
        case .masked, .validating, .valid, .saved, .invalid, .revoked:
            return String(repeating: "•", count: 20)
        case .reveal:
            return revealedText
        }
    }

    private func apiKeyShowsEditableTextField(state: APIKeyUIState, draft: String) -> Bool {
        switch state {
        case .blank, .focused, .typing:
            return true
        case .reveal:
            return !draft.isEmpty
        default:
            return false
        }
    }

    private func apiKeyPlaceholder(for state: APIKeyUIState) -> String? {
        switch state {
        case .blank, .focused:
            return "sk-..."
        default:
            return nil
        }
    }

    private func apiKeyUsesMaskedLetterSpacing(_ state: APIKeyUIState) -> Bool {
        switch state {
        case .masked, .validating, .valid, .saved, .invalid, .revoked:
            return true
        default:
            return false
        }
    }

    private func providerShowsEyeToggle(profile: ProviderProfile) -> Bool {
        let draft = viewModel.providerAPIKeyDrafts[profile.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !draft.isEmpty || viewModel.providerHasSavedAPIKeyIDs.contains(profile.id)
    }

    @ViewBuilder
    private func apiKeyInlineIndicator(for state: APIKeyUIState) -> some View {
        switch state {
        case .validating:
            ProgressView()
                .controlSize(.small)
                .tint(Color.quixoteBlue)
        case .valid, .saved:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.quixoteGreen)
        case .invalid:
            Image(systemName: "xmark.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.quixoteRed)
        case .revoked:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.quixoteOrange)
        default:
            EmptyView()
        }
    }

    private func apiKeyFieldBorderColor(for state: APIKeyUIState) -> Color {
        switch state {
        case .focused, .typing, .validating:
            return .quixoteBlue
        case .valid, .saved:
            return .quixoteGreen
        case .invalid:
            return .quixoteRed
        case .revoked:
            return .quixoteOrange
        default:
            return .quixoteDivider
        }
    }

    private func apiKeyFieldRingColor(for state: APIKeyUIState) -> Color {
        switch state {
        case .focused, .typing, .validating:
            return .quixoteBlue.opacity(0.22)
        case .valid, .saved:
            return .quixoteGreen.opacity(0.18)
        case .invalid:
            return .quixoteRed.opacity(0.20)
        case .revoked:
            return .quixoteOrange.opacity(0.18)
        default:
            return .clear
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
