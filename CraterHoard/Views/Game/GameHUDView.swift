import SwiftUI

/// The instruments around the shaft: gold and height up top, a stone height ruler on the left,
/// the lava thermometer on the right and the fulcrum dial at the bottom.
struct GameHUDView: View {
    let hud: GameHUDState
    let bestHeight: Int
    let callout: GameViewModel.Callout?
    let isVisible: Bool
    let onPause: () -> Void

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
            HStack(alignment: .bottom) {
                HeightRuler(height: hud.heightCentimetres, peak: hud.peakHeightCentimetres, best: bestHeight)
                Spacer()
                FulcrumDial(tilt: hud.tilt, steadyLimit: hud.steadyLimit, multiplier: hud.multiplier, cap: hud.multiplierCap)
                Spacer()
                LavaThermometer(level: hud.lavaLevel, capacity: hud.lavaCapacity)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
            .allowsHitTesting(false)
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

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    ArtImage("icon_gold").frame(width: 24, height: 24)
                    Text(Formatters.integer(hud.gold))
                        .font(.display(20, relativeTo: .headline))
                        .foregroundStyle(Theme.Colors.goldLight)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(hud.gold)))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Gold")
                .accessibilityValue(Formatters.integer(hud.gold))
                .accessibilityIdentifier(AccessibilityID.Game.gold)

                Rectangle().fill(Theme.Colors.copper.opacity(0.6)).frame(width: 1, height: 22)

                Text(Formatters.height(hud.heightCentimetres))
                    .font(.display(18, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.paper)
                    .monospacedDigit()
                    .accessibilityLabel("Hoard height")
                    .accessibilityValue(Formatters.height(hud.heightCentimetres))
                    .accessibilityIdentifier(AccessibilityID.Game.height)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background { PlateBackground() }
            .animation(.snappy, value: hud.gold)

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                ArtImage(hud.upcoming.coinArt)
                    .frame(width: 50, height: 22)
                    .frame(height: 24)
                Text("NEXT")
                    .font(.body(10, relativeTo: .caption2, bold: true))
                    .tracking(1.2)
                    .foregroundStyle(Theme.Colors.paper)
            }
            .frame(width: 66, height: 52)
            .background { PlateBackground() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Next coin")
            .accessibilityValue(hud.upcoming.title)
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 12)
    }
}

/// A short message tag after a weld, mint or warning.
private struct CalloutBanner: View {
    let callout: GameViewModel.Callout

    var body: some View {
        Text(callout.text)
            .font(.display(15, relativeTo: .subheadline))
            .foregroundStyle(textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(fillColor))
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.6), lineWidth: 1))
            .allowsHitTesting(false)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var fillColor: Color {
        switch callout.style {
        case .weld, .steady: Theme.Colors.patina
        case .mint: Theme.Colors.goldLight
        case .warning: Theme.Colors.danger
        }
    }

    private var textColor: Color {
        callout.style == .warning ? Theme.Colors.paper : Theme.Colors.ink
    }
}

/// Carved stone ruler with the current height and the best-ever mark.
private struct HeightRuler: View {
    let height: Int
    let peak: Int
    let best: Int

    var body: some View {
        let scale = Double(max(150, max(best, peak) + 40))
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                ArtImage("hud_ruler")
                GeometryReader { proxy in
                    let h = proxy.size.height
                    if best > 0 {
                        marker(color: Theme.Colors.goldLight)
                            .position(x: proxy.size.width / 2, y: h - h * min(1, Double(best) / scale))
                    }
                    marker(color: Theme.Colors.patina)
                        .position(x: proxy.size.width / 2, y: h - h * min(1, Double(height) / scale))
                        .animation(.easeOut(duration: 0.3), value: height)
                }
            }
            .frame(width: 26, height: 160)
            Text(best > 0 ? "BEST\n\(Formatters.height(best))" : "HEIGHT")
                .font(.body(10, relativeTo: .caption2, bold: true))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Colors.paper)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.65)))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Height ruler")
        .accessibilityValue("\(Formatters.height(height)), best \(Formatters.height(best))")
    }

    private func marker(color: Color) -> some View {
        Capsule()
            .fill(color)
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.8), lineWidth: 1))
            .frame(width: 34, height: 7)
    }
}

/// The balance dial: the needle shows the beam tilt, the patina arc is the steady zone.
private struct FulcrumDial: View {
    let tilt: Double
    let steadyLimit: Double
    let multiplier: Double
    let cap: Double

    private var isSteady: Bool { abs(tilt) <= steadyLimit }

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .bottom) {
                ArtImage("hud_dial")
                Canvas { context, size in
                    // Dial spans ±90° for ±maxTilt.
                    let center = CGPoint(x: size.width / 2, y: size.height * 0.914)
                    let radius = size.width * 0.32
                    let span = steadyLimit / Balance.maxTilt * (.pi / 2)
                    var arc = Path()
                    arc.addArc(center: center, radius: radius, startAngle: .radians(-.pi / 2 - span), endAngle: .radians(-.pi / 2 + span), clockwise: false)
                    context.stroke(arc, with: .color(Theme.Colors.patina), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                }
                ArtImage("hud_needle")
                    .frame(width: 8, height: 46)
                    .offset(y: -6)
                    .rotationEffect(.radians(min(1, max(-1, tilt / Balance.maxTilt)) * .pi / 2), anchor: UnitPoint(x: 0.5, y: 0.87))
                    .animation(.easeOut(duration: 0.2), value: tilt)
                    .offset(y: -1)
            }
            .frame(width: 120, height: 70)
            Text(isSteady ? "STEADY \(Formatters.multiplier(multiplier))" : "TIPPING")
                .font(.display(13, relativeTo: .caption))
                .foregroundStyle(isSteady ? Theme.Colors.ink : Theme.Colors.paper)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(isSteady ? (multiplier >= cap ? Theme.Colors.goldLight : Theme.Colors.patina) : Theme.Colors.danger))
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.6), lineWidth: 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fulcrum dial")
        .accessibilityValue(isSteady ? "Steady, multiplier \(Formatters.multiplier(multiplier))" : "Tipping")
        .accessibilityIdentifier(AccessibilityID.Game.dial)
    }
}

/// Glass thermometer whose lava column rises one notch per spilled coin.
private struct LavaThermometer: View {
    let level: Int
    let capacity: Int

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                GeometryReader { proxy in
                    let tube = CGRect(x: proxy.size.width * 0.3, y: proxy.size.height * 0.04, width: proxy.size.width * 0.4, height: proxy.size.height * 0.85)
                    let fraction = capacity == 0 ? 0 : Double(level) / Double(capacity)
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.Colors.lavaHot, Theme.Colors.lava], startPoint: .top, endPoint: .bottom))
                        .frame(width: tube.width - 4, height: max(0, tube.height * fraction))
                        .position(x: tube.midX, y: tube.maxY - tube.height * fraction / 2)
                        .animation(.spring(duration: 0.5), value: level)
                    ForEach(1..<max(capacity, 1), id: \.self) { notch in
                        Rectangle()
                            .fill(Theme.Colors.paper)
                            .frame(width: 9, height: 2)
                            .position(x: tube.minX - 4, y: tube.maxY - tube.height * Double(notch) / Double(capacity))
                    }
                }
                ArtImage("hud_thermo")
            }
            .frame(width: 34, height: 160)
            Text("LAVA\n\(level)/\(capacity)")
                .font(.body(10, relativeTo: .caption2, bold: true))
                .multilineTextAlignment(.center)
                .foregroundStyle(level >= capacity - 1 ? Theme.Colors.lavaHot : Theme.Colors.paper)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.65)))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lava level")
        .accessibilityValue("\(level) of \(capacity) notches")
        .accessibilityIdentifier(AccessibilityID.Game.lava)
    }
}
