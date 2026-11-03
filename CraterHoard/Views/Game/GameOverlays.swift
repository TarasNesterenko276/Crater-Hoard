import SwiftUI

/// Before the shift: a paper briefing with the keeper and the loadout numbers that matter.
struct ShiftBriefingOverlay: View {
    let keeper: Keeper
    let loadout: Loadout
    let bestBank: Int
    let bestScore: Int
    let onStart: () -> Void
    let onLeave: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ArtImage(keeper.portraitArt)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(Theme.Colors.patinaDark))
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Theme.Colors.copper, lineWidth: 2.5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shift briefing")
                            .font(.body(12, relativeTo: .caption, bold: true))
                            .tracking(1.4)
                            .foregroundStyle(Theme.Colors.copperDark)
                        Text("\(keeper.name) in the cart")
                            .font(.display(22, relativeTo: .title2))
                            .foregroundStyle(Theme.Colors.ink)
                        Text(keeper.perkTitle + " · " + keeper.perkDetail)
                            .font(.body(13, relativeTo: .caption))
                            .foregroundStyle(Theme.Colors.inkSoft)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    fact("Planks", "\(loadout.planks)")
                    fact("Heat tank", "\(Int(loadout.heatCapacity))")
                    fact("Rail switch", "\(Formatters.oneDecimal(loadout.switchTime)) s")
                }

                Text("Drag to roll · swipe up/down to change rails · tap to dash")
                    .font(.body(13, relativeTo: .caption, bold: true))
                    .foregroundStyle(Theme.Colors.copperDark)
                    .multilineTextAlignment(.center)

                if bestScore > 0 {
                    Text("Your best: \(Formatters.integer(bestScore)) pts · best haul \(Formatters.integer(bestBank)) gold")
                        .font(.body(14, bold: true))
                        .foregroundStyle(Theme.Colors.inkSoft)
                }

                Button(action: onStart) {
                    Text("ROLL OUT")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CopperButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.start)

                Button(action: onLeave) {
                    Text("Back to the vault")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PaperButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.leave)
            }
            .padding(18)
            .background { PaperBackground(cornerRadius: 22) }
            .frame(maxWidth: 460)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .accessibilityElement(children: .contain)
    }

    private func fact(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.display(18, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.ink)
            Text(title)
                .font(.body(11, relativeTo: .caption2, bold: true))
                .foregroundStyle(Theme.Colors.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Colors.paperShade.opacity(0.5)))
        .accessibilityElement(children: .combine)
    }
}

/// 3-2-1 stamped in copper.
struct CountdownOverlay: View {
    let value: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            Text("\(value)")
                .font(.display(110, relativeTo: .largeTitle))
                .foregroundStyle(Theme.Colors.goldLight)
                .shadow(color: .black.opacity(0.8), radius: 0, x: 3, y: 4)
                .id(value)
                .transition(.scale(scale: 1.6).combined(with: .opacity))
            Text("Starting in \(value)")
                .font(.body(15, bold: true))
                .foregroundStyle(Theme.Colors.paper)
                .offset(y: 90)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Starting in \(value)")
        .accessibilityIdentifier(AccessibilityID.Game.countdown)
    }
}

/// Paused: the shift is frozen until the player resumes.
struct PauseOverlay: View {
    let hud: GameHUDState
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Shift paused")
                    .font(.display(28, relativeTo: .title))
                    .foregroundStyle(Theme.Colors.ink)
                Text("\(Formatters.integer(hud.gold)) gold banked · \(hud.cargoCount) coins in the cart · \(hud.planks) planks left")
                    .font(.body(15, bold: true))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .multilineTextAlignment(.center)
                Button(action: onResume) {
                    Text("RESUME").frame(maxWidth: .infinity)
                }
                .buttonStyle(CopperButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.resume)
                HStack(spacing: 10) {
                    Button(action: onRestart) {
                        Text("Restart").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PaperButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.restart)
                    Button(action: onQuit) {
                        Text("Leave shift").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PaperButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.quit)
                }
                Text("Leaving ends the shift without banking its gold.")
                    .font(.body(12, relativeTo: .caption))
                    .foregroundStyle(Theme.Colors.inkSoft)
            }
            .padding(20)
            .background { PaperBackground(cornerRadius: 22) }
            .frame(maxWidth: 400)
            .padding(24)
        }
        .accessibilityElement(children: .contain)
    }
}

/// End of shift: the foreman's chalk slate with tally marks, and the mine cart hauling the gold.
struct ChalkSlateOverlay: View {
    let outcome: RunOutcome
    let keeper: Keeper
    let onAgain: () -> Void
    let onAssay: () -> Void
    let onVault: () -> Void

    @State private var revealed = false

    private var summary: RunSummary { outcome.summary }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    ArtImage("mine_cart")
                        .frame(width: 190)
                        .offset(x: revealed ? 0 : -400)
                        .padding(.bottom, -18)
                        .zIndex(1)
                    slate
                    buttons
                        .padding(.top, 14)
                }
                .frame(maxWidth: 440)
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.25).delay(0.15)) { revealed = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Game.slate)
    }

    private var slate: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(outcome.isNewBestScore ? "New record!" : "Shift over")
                    .font(.display(30, relativeTo: .largeTitle))
                    .foregroundStyle(outcome.isNewBestScore ? Theme.Colors.goldLight : Theme.Colors.chalk)
                Spacer()
                Text("\(Formatters.integer(summary.score))")
                    .font(.display(30, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.Colors.chalk)
                    .monospacedDigit()
                    .accessibilityLabel("Score \(Formatters.integer(summary.score))")
            }
            Text("The cart is out of planks. \(keeper.name) pushed it back down to the vault.")
                .font(.body(14))
                .foregroundStyle(Theme.Colors.chalk.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            ChalkRule()
            row("Gold banked", "+\(Formatters.integer(summary.gold))", note: "vault: \(Formatters.integer(outcome.totalGold))")
            row("Best haul", Formatters.integer(summary.bestBank), note: outcome.isNewBestBank ? "best ever" : nil)
            row("Coins caught", Formatters.integer(summary.coinsCaught), note: nil)
            tallyRow("Volcanic cores", summary.coresCaught)
            tallyRow("Boulders broken", summary.bouldersBroken)
            tallyRow("Lightning caught", summary.lightningCaught)
            row("Shift length", Formatters.duration(summary.duration), note: nil)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(ImagePaint(image: Image("tex_slate"), scale: 1))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                    LinearGradient(colors: [Theme.Colors.woodLight, Theme.Colors.woodDark], startPoint: .top, endPoint: .bottom),
                    lineWidth: 10
                ))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.black.opacity(0.7), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
        }
    }

    private func row(_ title: String, _ value: String, note: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.body(16))
                .foregroundStyle(Theme.Colors.chalk.opacity(0.9))
            Spacer()
            if let note {
                Text(note)
                    .font(.body(12, relativeTo: .caption, bold: true))
                    .foregroundStyle(Theme.Colors.goldLight)
            }
            Text(value)
                .font(.display(19, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.chalk)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func tallyRow(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title)
                .font(.body(16))
                .foregroundStyle(Theme.Colors.chalk.opacity(0.9))
            Spacer()
            if count == 0 {
                Text("none")
                    .font(.body(15))
                    .foregroundStyle(Theme.Colors.chalk.opacity(0.6))
            } else if count <= 15 {
                TallyMarks(count: count)
                    .frame(width: CGFloat((count + 4) / 5) * 30, height: 20)
            } else {
                Text("\(count)")
                    .font(.display(19, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.chalk)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(count)")
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button(action: onAgain) {
                Text("RIDE UP AGAIN").frame(maxWidth: .infinity)
            }
            .buttonStyle(CopperButtonStyle())
            .accessibilityIdentifier(AccessibilityID.Game.again)
            HStack(spacing: 10) {
                Button(action: onAssay) {
                    Text("Assay Shelf").frame(maxWidth: .infinity)
                }
                .buttonStyle(PaperButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.toAssay)
                Button(action: onVault) {
                    Text("To the vault").frame(maxWidth: .infinity)
                }
                .buttonStyle(PaperButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.toVault)
            }
        }
    }
}

/// Hand-drawn chalk tally marks in groups of five.
private struct TallyMarks: View {
    let count: Int

    var body: some View {
        Canvas { context, size in
            let groups = (count + 4) / 5
            for group in 0..<groups {
                let originX = CGFloat(group) * 30
                let marks = min(5, count - group * 5)
                for mark in 0..<min(marks, 4) {
                    var path = Path()
                    let x = originX + 3 + CGFloat(mark) * 5.5
                    path.move(to: CGPoint(x: x, y: 2 + CGFloat(mark % 2)))
                    path.addLine(to: CGPoint(x: x + 0.8, y: size.height - 2))
                    context.stroke(path, with: .color(Theme.Colors.chalk), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
                if marks == 5 {
                    var slash = Path()
                    slash.move(to: CGPoint(x: originX, y: size.height - 4))
                    slash.addLine(to: CGPoint(x: originX + 25, y: 4))
                    context.stroke(slash, with: .color(Theme.Colors.chalk), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ChalkRule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.chalk.opacity(0.4))
            .frame(height: 1.5)
            .accessibilityHidden(true)
    }
}

extension Theme.Colors {
    static let woodLight = Color(red: 0.66, green: 0.45, blue: 0.25)
    static let woodDark = Color(red: 0.29, green: 0.17, blue: 0.09)
}
