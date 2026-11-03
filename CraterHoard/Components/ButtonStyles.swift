import SwiftUI

/// The main call-to-action: a riveted copper plate that sinks when pressed.
struct CopperButtonStyle: ButtonStyle {
    var tint: Color = Theme.Colors.copper
    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.display(isProminent ? 22 : 17, relativeTo: .headline))
            .tracking(1.2)
            .foregroundStyle(Theme.Colors.paper)
            .shadow(color: .black.opacity(0.45), radius: 0, y: 1.5)
            .padding(.vertical, isProminent ? 16 : 11)
            .padding(.horizontal, 22)
            .frame(minHeight: Theme.Metrics.minimumTap)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.Colors.copperDark.mix(with: .black, by: 0.35))
                    .offset(y: pressed ? 1 : 4)
            }
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [tint.mix(with: .white, by: 0.25), tint, tint.mix(with: .black, by: 0.3)], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.75), lineWidth: 1.5)
                    }
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.28))
                            .frame(height: 3)
                            .padding(.horizontal, 14)
                            .padding(.top, 5)
                    }
                    .offset(y: pressed ? 3 : 0)
            }
            .offset(y: pressed ? 3 : 0)
            .animation(.spring(duration: 0.18), value: pressed)
    }
}

/// A quieter button printed on paper: ink text inside a copper-ruled outline.
struct PaperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body(17, relativeTo: .headline, bold: true))
            .foregroundStyle(Theme.Colors.ink)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .frame(minHeight: Theme.Metrics.minimumTap)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.Colors.paper.opacity(configuration.isPressed ? 0.7 : 1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.Colors.copperDark, lineWidth: 1.5)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

/// Scales any tapped diegetic object (vault items) down slightly while pressed.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}
