import SwiftUI

/// A generated artwork from the asset catalog, scaled to fit its frame.
struct ArtImage: View {
    let name: String

    init(_ name: String) {
        self.name = name
    }

    var body: some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

/// The 9-slice copper plate behind HUD numbers and badges.
struct PlateBackground: View {
    var body: some View {
        Image("plate")
            .resizable(capInsets: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14), resizingMode: .stretch)
            .accessibilityHidden(true)
    }
}

/// The 9-slice wooden plaque used for panel titles.
struct PlaqueBackground: View {
    var body: some View {
        Image("plaque")
            .resizable(capInsets: EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18), resizingMode: .stretch)
            .accessibilityHidden(true)
    }
}

/// Tiled assay paper with a copper rule, used for readable panels.
struct PaperBackground: View {
    var cornerRadius: CGFloat = Theme.Metrics.corner

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(ImagePaint(image: Image("tex_paper"), scale: 1))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Colors.copperDark.opacity(0.8), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }
}

/// Gold balance shown on a copper plate.
struct GoldBadge: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            ArtImage("icon_gold")
                .frame(width: 26, height: 26)
            Text(Formatters.integer(amount))
                .font(.display(19, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.goldLight)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(amount)))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background { PlateBackground() }
        .animation(.snappy, value: amount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gold")
        .accessibilityValue(Formatters.integer(amount))
    }
}
