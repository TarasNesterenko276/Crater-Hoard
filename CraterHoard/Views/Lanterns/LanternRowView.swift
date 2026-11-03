import SwiftUI

/// Keepers glow inside a row of hanging mine lanterns. Tap a lantern to light it,
/// then hire or send that keeper to the claw.
struct LanternRowView: View {
    @State private var viewModel: LanternsViewModel

    init(viewModel: LanternsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                lanternRail
                focusCard
                    .padding(.horizontal, 18)
                    .frame(maxWidth: Theme.Metrics.maxContentWidth)
            }
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .toast(message: $viewModel.toastMessage, isError: viewModel.toastIsError)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Lanterns.screen)
    }

    /// Two copper rods with three lanterns each, so every keeper is visible without scrolling.
    private var lanternRail: some View {
        let rows = stride(from: 0, to: Keeper.allCases.count, by: 3).map { Array(Keeper.allCases[$0..<min($0 + 3, Keeper.allCases.count)]) }
        return VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.element) { index, keeper in
                        LanternButton(
                            keeper: keeper,
                            isHired: viewModel.isHired(keeper),
                            isFocused: keeper == viewModel.focused,
                            isAtClaw: keeper == viewModel.selected,
                            drop: CGFloat([8, 22, 12, 18, 6, 24][(rowIndex * 3 + index) % 6])
                        ) {
                            withAnimation(.spring(duration: 0.35)) { viewModel.focus(keeper) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .background(alignment: .top) {
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.Colors.copperLight, Theme.Colors.copperDark], startPoint: .top, endPoint: .bottom))
                        .frame(height: 8)
                        .overlay(Capsule().strokeBorder(Color.black.opacity(0.7), lineWidth: 1))
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: Theme.Metrics.maxContentWidth)
    }

    private var focusCard: some View {
        let keeper = viewModel.focused
        let hired = viewModel.isHired(keeper)
        return VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                ArtImage(keeper.portraitArt)
                    .frame(width: 110, height: 110)
                    .saturation(hired ? 1 : 0.2)
                    .background(Circle().fill(Theme.Colors.patinaDark.opacity(0.85)))
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Theme.Colors.copper, lineWidth: 3))
                VStack(alignment: .leading, spacing: 2) {
                    Text(keeper.name)
                        .font(.display(26, relativeTo: .title))
                        .foregroundStyle(Theme.Colors.ink)
                        .accessibilityIdentifier(AccessibilityID.Lanterns.selectedName)
                    Text(keeper.species)
                        .font(.body(15, relativeTo: .subheadline, bold: true))
                        .foregroundStyle(Theme.Colors.inkSoft)
                    perkTag(keeper)
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            Text(keeper.perkDetail)
                .font(.body(16))
                .foregroundStyle(Theme.Colors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            actionButton(keeper)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Colors.paperShade.opacity(0.45))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.Colors.copperDark.opacity(0.5), lineWidth: 1))
        }
        .animation(.spring(duration: 0.3), value: keeper)
    }

    private func perkTag(_ keeper: Keeper) -> some View {
        Text(keeper.perkTitle)
            .font(.display(14, relativeTo: .footnote))
            .foregroundStyle(Theme.Colors.ink)
            .padding(.leading, 22)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background {
                Image("tag_perk")
                    .resizable(capInsets: EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 8), resizingMode: .stretch)
            }
    }

    @ViewBuilder
    private func actionButton(_ keeper: Keeper) -> some View {
        switch viewModel.action(for: keeper) {
        case .hire(let price):
            Button(action: viewModel.performAction) {
                HStack(spacing: 8) {
                    Text("Hire \(keeper.name)")
                    ArtImage("icon_gold").frame(width: 22, height: 22)
                    Text(Formatters.integer(price)).monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(CopperButtonStyle(tint: viewModel.gold >= price ? Theme.Colors.copper : Color(white: 0.45), isProminent: false))
            .accessibilityIdentifier(AccessibilityID.Lanterns.action)
        case .select:
            Button(action: viewModel.performAction) {
                Text("Send \(keeper.name) to the claw")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(CopperButtonStyle(tint: Theme.Colors.patinaDark, isProminent: false))
            .accessibilityIdentifier(AccessibilityID.Lanterns.action)
        case .atTheClaw:
            Label("\(keeper.name) is at the claw", systemImage: "hand.raised.fill")
                .font(.display(16, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.patinaDark)
                .frame(maxWidth: .infinity, minHeight: Theme.Metrics.minimumTap)
                .accessibilityIdentifier(AccessibilityID.Lanterns.action)
        }
    }
}

/// One hanging lantern: the keeper's portrait glows behind the glass when hired.
private struct LanternButton: View {
    let keeper: Keeper
    let isHired: Bool
    let isFocused: Bool
    let isAtClaw: Bool
    let drop: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.Colors.copperDark)
                    .frame(width: 2, height: drop)
                ZStack {
                    ArtImage(keeper.portraitArt)
                        .frame(width: 66, height: 66)
                        .saturation(isHired ? 1 : 0)
                        .brightness(isHired ? 0 : -0.35)
                        .offset(y: 6)
                        .background(isHired ? Theme.Colors.lavaHot.opacity(0.35) : Color.black.opacity(0.4))
                        .frame(width: 62, height: 82)
                        .clipped()
                        .offset(y: 5)
                    ArtImage("lantern_frame")
                        .frame(width: 98, height: 140)
                    if !isHired {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.Colors.paper)
                            .padding(7)
                            .background(Circle().fill(Color.black.opacity(0.65)))
                            .offset(y: 8)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: 98, height: 140)
                .scaleEffect(isFocused ? 1.08 : 0.94)
                .shadow(color: isFocused ? Theme.Colors.lavaHot.opacity(0.8) : .clear, radius: 12)
                Text(keeper.name)
                    .font(.display(14, relativeTo: .caption))
                    .foregroundStyle(isFocused ? Theme.Colors.ink : Theme.Colors.inkSoft)
                    .padding(.top, 2)
                if isAtClaw {
                    Text("AT CLAW")
                        .font(.body(10, relativeTo: .caption2, bold: true))
                        .tracking(1)
                        .foregroundStyle(Theme.Colors.paper)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.Colors.patinaDark))
                }
            }
            .padding(.top, 4)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keeper.name)
        .accessibilityValue(isAtClaw ? "At the claw" : isHired ? "Hired" : "Locked, \(Formatters.integer(keeper.price)) gold")
        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(AccessibilityID.Lanterns.lantern(keeper))
    }
}
