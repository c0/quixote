import SwiftUI

extension Color {
    static let quixoteAppBackground = Color(red: 0.09, green: 0.09, blue: 0.10)
    static let quixotePanel = Color(red: 0.13, green: 0.13, blue: 0.14)
    static let quixotePanelRaised = Color(red: 0.16, green: 0.16, blue: 0.17)
    static let quixoteCard = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let quixoteDivider = Color.white.opacity(0.08)
    static let quixoteTextPrimary = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let quixoteTextSecondary = Color(red: 0.56, green: 0.59, blue: 0.68)
    static let quixoteTextMuted = Color(red: 0.43, green: 0.45, blue: 0.51)
    static let quixoteSelection = Color(red: 0.22, green: 0.22, blue: 0.24)
    static let quixoteBlue = Color(red: 0.19, green: 0.42, blue: 0.94)
    static let quixoteBlueMuted = Color(red: 0.28, green: 0.55, blue: 1.0)
    static let quixoteGreen = Color(red: 0.22, green: 0.86, blue: 0.48)
    static let quixoteRed = Color(red: 0.83, green: 0.16, blue: 0.27)
    static let quixoteOrange = Color(red: 0.95, green: 0.62, blue: 0.23)
}

enum QuixoteSpacing {
    static let shell: CGFloat = 14
    static let paneInset: CGFloat = 18
    static let sectionGap: CGFloat = 18
    static let controlGap: CGFloat = 10
    static let cornerRadius: CGFloat = 14
    static let smallRadius: CGFloat = 10
}

struct QuixoteSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold, design: .default))
            .tracking(2.4)
            .foregroundStyle(Color.quixoteTextSecondary)
    }
}

struct QuixotePaneDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.quixoteDivider)
            .frame(width: 1)
    }
}

struct QuixoteRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.quixoteDivider)
            .frame(height: 1)
    }
}

struct QuixotePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                    .fill(Color.quixoteBlue.opacity(configuration.isPressed ? 0.85 : 1))
            )
    }
}

struct QuixoteSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(Color.quixoteTextPrimary.opacity(configuration.isPressed ? 0.85 : 1))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                    .fill(Color.quixotePanelRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: QuixoteSpacing.cornerRadius, style: .continuous)
                            .stroke(Color.quixoteDivider, lineWidth: 1)
                    )
            )
    }
}

struct QuixoteChip: View {
    private static let maxTextWidth: CGFloat = 220

    let text: String
    var actionIcon: String? = nil
    var tint: Color = .quixoteTextPrimary
    var fill: Color = .quixoteSelection

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: Self.maxTextWidth, alignment: .leading)

            if let actionIcon {
                Image(systemName: actionIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.quixoteTextSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(fill)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.quixoteDivider, lineWidth: 1)
                )
        )
    }
}
