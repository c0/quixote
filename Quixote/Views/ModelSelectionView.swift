import SwiftUI

struct ModelPickerPopover: View {
    let groupedModels: [(family: String, models: [ModelConfig])]
    let selectedIDs: Set<String>
    let onToggle: (String) -> Void
    let onSelectAll: ([ModelConfig]) -> Void
    let onDeselectAll: ([ModelConfig]) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(groupedModels, id: \.family) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(group.family.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(Color.quixoteTextSecondary)

                            Spacer()

                            Button("All") { onSelectAll(group.models) }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundStyle(Color.quixoteBlueMuted)

                            Button("None") { onDeselectAll(group.models) }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundStyle(Color.quixoteTextSecondary)
                        }

                        ForEach(group.models) { model in
                            Toggle(model.displayName, isOn: toggleBinding(for: model.id))
                                .toggleStyle(.checkbox)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.quixoteTextPrimary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: QuixoteSpacing.smallRadius, style: .continuous)
                            .fill(Color.quixotePanel)
                            .overlay(
                                RoundedRectangle(cornerRadius: QuixoteSpacing.smallRadius, style: .continuous)
                                    .stroke(Color.quixoteDivider, lineWidth: 1)
                            )
                    )
                }
            }
            .padding(12)
        }
        .frame(width: 280, height: 320)
        .background(Color.quixoteAppBackground)
    }

    private func toggleBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(id) },
            set: { _ in onToggle(id) }
        )
    }
}
