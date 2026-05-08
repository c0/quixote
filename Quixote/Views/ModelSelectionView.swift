import SwiftUI

struct SingleModelPickerPopover: View {
    let groupedModels: [(family: String, models: [ModelConfig])]
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(groupedModels, id: \.family) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.family.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(Color.quixoteTextSecondary)

                        ForEach(group.models, id: \.selectionKey) { model in
                            Button {
                                onSelect(model.selectionKey)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedID == model.selectionKey ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(selectedID == model.selectionKey ? Color.quixoteBlue : Color.quixoteTextMuted)

                                    Text(model.displayName)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.quixoteTextPrimary)

                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selectedID == model.selectionKey ? Color.quixoteSelection : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
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
}
