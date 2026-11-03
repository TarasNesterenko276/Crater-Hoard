import SwiftUI

/// The instruments around the slope: planks, gold and the ash meter up top,
/// the cart's heat thermometer and cargo plate, and the rail and dash levers in the thumb zone.
struct GameHUDView: View {
    let hud: GameHUDState
    let callout: GameViewModel.Callout?
    let isVisible: Bool
    let onPause: () -> Void
    let onSwitch: () -> Void
    let onDash: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let callout {
                CalloutBanner(callout: callout)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(callout.id)
            }
            Spacer(minLength: 0)
            bottomBar
        }
        .padding(.top, 6)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: isVisible)
        .animation(.spring(duration: 0.3), value: callout)
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onPause) {
                ZStack {
                    ArtImage("medallion")
                    Image(systemName: "pause.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Colors.paper)
                }
                .frame(width: 50, height: 50)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Pause")
            .accessibilityIdentifier(AccessibilityID.Game.pause)

            PlankRow(planks: hud.planks, maxPlanks: hud.maxPlanks)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                ArtImage("icon_gold").frame(width: 24, height: 24)
                Text(Formatters.integer(hud.gold))
                    .font(.display(20, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.goldLight)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(hud.gold)))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background { PlateBackground() }
            .animation(.snappy, value: hud.gold)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Gold banked")
            .accessibilityValue(Formatters.integer(hud.gold))
            .accessibilityIdentifier(AccessibilityID.Game.gold)

            AshMeter(ash: hud.ash, isStorm: hud.isAshStorm)
        }
        .padding(.horizontal, 12)
    }

    private var bottomBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            LeverButton(
                title: hud.rail == .upper ? "DOWN" : "UP",
                systemImage: hud.rail == .upper ? "arrow.down" : "arrow.up",
                isEnabled: !hud.isSwitching,
                action: onSwitch
            )
            .accessibilityLabel(hud.rail == .upper ? "Switch to the lower rail" : "Switch to the upper rail")
            .accessibilityIdentifier(AccessibilityID.Game.switchRail)

            HeatGauge(fraction: hud.heatFraction)
            Spacer(minLength: 0)
            CargoPlate(count: hud.cargoCount, multiplier: hud.cargoMultiplier, bankSide: hud.bankSide)
            Spacer(minLength: 0)

            LeverButton(title: "DASH", systemImage: "bolt.fill", isEnabled: hud.canDash, action: onDash)
                .accessibilityLabel("Dash")
                .accessibilityIdentifier(AccessibilityID.Game.dash)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
}

/// Wooden planks of the cart's armour: the shift ends when none are left.
private struct PlankRow: View {
    let planks: Int
    let maxPlanks: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<maxPlanks, id: \.self) { index in
                ArtImage(index < planks ? "plank" : "plank_broken")
                    .frame(width: 20, height: 34)
                    .opacity(index < planks ? 1 : 0.6)
            }
        }
        .animation(.spring(duration: 0.3), value: planks)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cart planks")
        .accessibilityValue("\(planks) of \(maxPlanks)")
        .accessibilityIdentifier(AccessibilityID.Game.planks)
    }
}

/// How thick the ash cloud is. Lightning sparks above the line.
private struct AshMeter: View {
    let ash: Double
    let isStorm: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .bottom) {
                Capsule().fill(Color.black.opacity(0.6))
                Capsule()
                    .fill(LinearGradient(colors: [Color(white: 0.75), Color(white: 0.35)], startPoint: .top, endPoint: .bottom))
                    .frame(height: max(4, 40 * ash))
                Rectangle()
                    .fill(Theme.Colors.lightningBlue)
                    .frame(height: 2)
                    .offset(y: -40 * Balance.lightningThreshold)
            }
            .frame(width: 14, height: 40)
            .overlay(Capsule().strokeBorder(Theme.Colors.copper, lineWidth: 1.5))
            Image(systemName: isStorm ? "cloud.bolt.fill" : "cloud.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isStorm ? Theme.Colors.lightningBlue : Theme.Colors.paper)
        }
        .animation(.easeOut(duration: 0.3), value: ash)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ash cloud")
        .accessibilityValue(isStorm ? "Storm, lightning possible" : "\(Formatters.percent(ash))")
        .accessibilityIdentifier(AccessibilityID.Game.ash)
    }
}

/// The cart's thermometer: bank before it reaches the top.
private struct HeatGauge: View {
    let fraction: Double

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                GeometryReader { proxy in
                    let tube = CGRect(x: proxy.size.width * 0.3, y: proxy.size.height * 0.04, width: proxy.size.width * 0.4, height: proxy.size.height * 0.85)
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.Colors.lavaHot, Theme.Colors.lava], startPoint: .top, endPoint: .bottom))
                        .frame(width: tube.width - 4, height: max(0, tube.height * fraction))
                        .position(x: tube.midX, y: tube.maxY - tube.height * fraction / 2)
                        .animation(.easeOut(duration: 0.2), value: fraction)
                }
                ArtImage("hud_thermo")
            }
            .frame(width: 30, height: 120)
            Text("HEAT")
                .font(.body(10, relativeTo: .caption2, bold: true))
                .foregroundStyle(fraction > 0.75 ? Theme.Colors.lavaHot : Theme.Colors.paper)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.65)))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cart heat")
        .accessibilityValue(Formatters.percent(fraction))
        .accessibilityIdentifier(AccessibilityID.Game.heat)
    }
}

/// Coins in the cart, the multiplier they would bank at, and which way the mine is.
private struct CargoPlate: View {
    let count: Int
    let multiplier: Double
    let bankSide: Double

    var body: some View {
        HStack(spacing: 8) {
            if bankSide < 0 { arrow("arrowshape.left.fill") }
            VStack(spacing: 0) {
                Text(count == 0 ? "EMPTY" : "\(count) coins")
                    .font(.display(16, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.paper)
                Text(count == 0 ? "catch coins" : "bank \(Formatters.multiplier(multiplier))")
                    .font(.body(12, relativeTo: .caption, bold: true))
                    .foregroundStyle(Theme.Colors.goldLight)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            if bankSide > 0 { arrow("arrowshape.right.fill") }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background { PlateBackground() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cargo")
        .accessibilityValue(count == 0 ? "Empty" : "\(count) coins, banks at \(Formatters.multiplier(multiplier)), mine to the \(bankSide < 0 ? "left" : "right")")
        .accessibilityIdentifier(AccessibilityID.Game.cargo)
    }

    private func arrow(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(count > 0 ? Theme.Colors.patina : Theme.Colors.paper.opacity(0.4))
            .accessibilityHidden(true)
    }
}

/// A round copper lever in the thumb zone.
private struct LeverButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .heavy))
                Text(title)
                    .font(.display(11, relativeTo: .caption2))
            }
            .foregroundStyle(Theme.Colors.paper)
            .frame(width: 64, height: 64)
            .background {
                ZStack {
                    ArtImage("medallion")
                    Circle().fill(Color.black.opacity(isEnabled ? 0 : 0.4)).padding(6)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
    }
}

/// A short message tag after a bank, hit or storm.
private struct CalloutBanner: View {
    let callout: GameViewModel.Callout

    var body: some View {
        Text(callout.text)
            .font(.display(15, relativeTo: .subheadline))
            .foregroundStyle(callout.style == .warning ? Theme.Colors.paper : Theme.Colors.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(fillColor))
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.6), lineWidth: 1))
            .allowsHitTesting(false)
            .accessibilityIdentifier(AccessibilityID.Game.callout)
    }

    private var fillColor: Color {
        switch callout.style {
        case .weld, .steady: Theme.Colors.lightningBlue
        case .mint: Theme.Colors.goldLight
        case .warning: Theme.Colors.danger
        }
    }
}

extension Theme.Colors {
    static let lightningBlue = Color(red: 0.62, green: 0.88, blue: 1.0)
}
