import SwiftUI

/// The hub: a cave vault under the crater. Every object in the room is a door to a panel,
/// and the lift cage carries the keeper up to the crater for a shift.
struct VaultView: View {
    @State private var viewModel: VaultViewModel
    let animatesEmbers: Bool
    let onOpen: (VaultPanel) -> Void
    let onPlay: () -> Void

    init(viewModel: VaultViewModel, animatesEmbers: Bool, onOpen: @escaping (VaultPanel) -> Void, onPlay: @escaping () -> Void) {
        self.viewModel = viewModel
        self.animatesEmbers = animatesEmbers
        self.onOpen = onOpen
        self.onPlay = onPlay
    }

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height * 1.15
            let unit = isWide
                ? min(proxy.size.height * 0.19, proxy.size.width * 0.14)
                : min(proxy.size.width * 0.29, proxy.size.height * 0.15, 170)

            VStack(spacing: 0) {
                topBar
                if isWide {
                    HStack(alignment: .center, spacing: 24) {
                        VStack(spacing: 10) {
                            logo(width: min(380, proxy.size.width * 0.36))
                            Spacer(minLength: 0)
                            lift(unit: unit * 1.2)
                        }
                        chamber(unit: unit)
                    }
                    .padding(.horizontal, 28)
                } else {
                    logo(width: min(360, proxy.size.width * 0.86))
                    Spacer(minLength: 6)
                    chamber(unit: unit)
                    Spacer(minLength: 6)
                    lift(unit: unit * 1.25)
                }
            }
            .padding(.bottom, 12)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background {
            GeometryReader { proxy in
                ZStack {
                    Image("bg_vault")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                    EmberDrift(isActive: animatesEmbers)
                }
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Vault.screen)
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack(alignment: .center) {
            GoldBadge(amount: viewModel.gold)
                .accessibilityIdentifier(AccessibilityID.Vault.gold)
            Spacer()
            Button {
                viewModel.tapped()
                onOpen(.settings)
            } label: {
                ArtImage("item_valve")
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(PressableStyle())
            .frame(minWidth: 48, minHeight: 48)
            .accessibilityLabel("Settings")
            .accessibilityIdentifier(AccessibilityID.Vault.settings)
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }

    private func logo(width: CGFloat) -> some View {
        ArtImage("logo_wordmark")
            .frame(width: width)
            .accessibilityElement()
            .accessibilityLabel("Crater Hoard")
            .accessibilityAddTraits(.isHeader)
    }

    private func chamber(unit: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(spacing: 16) {
                VaultObject(art: "item_shelf", title: "Assay Shelf", hint: "Upgrades", size: unit, badge: viewModel.affordableUpgrades) {
                    open(.assay)
                }
                .accessibilityIdentifier(AccessibilityID.Vault.assay)
                VaultObject(art: "item_core", title: "Core Sample", hint: "Records", size: unit, badge: 0) {
                    open(.core)
                }
                .accessibilityIdentifier(AccessibilityID.Vault.core)
            }
            centerpiece(unit: unit)
            VStack(spacing: 16) {
                VaultObject(art: "item_lanterns", title: "Lantern Row", hint: "Keepers", size: unit, badge: 0) {
                    open(.lanterns)
                }
                .accessibilityIdentifier(AccessibilityID.Vault.lanterns)
                VaultObject(art: "item_board", title: "Notice Board", hint: "How to play", size: unit, badge: viewModel.needsGuide ? 1 : 0) {
                    open(.guide)
                }
                .accessibilityIdentifier(AccessibilityID.Vault.board)
            }
        }
        .padding(.horizontal, 10)
    }

    private func centerpiece(unit: CGFloat) -> some View {
        VStack(spacing: 8) {
            ArtImage("hub_balance")
                .frame(width: unit * 1.15)
            Button {
                open(.lanterns)
            } label: {
                HStack(spacing: 8) {
                    ArtImage(viewModel.keeper.portraitArt)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.Colors.patinaDark))
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Theme.Colors.copper, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(viewModel.keeper.name)
                            .font(.display(15, relativeTo: .subheadline))
                            .foregroundStyle(Theme.Colors.ink)
                        Text(viewModel.keeper.perkTitle)
                            .font(.body(12, relativeTo: .caption))
                            .foregroundStyle(Theme.Colors.inkSoft)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .padding(.leading, 4)
                .padding(.trailing, 12)
                .padding(.vertical, 4)
                .background { PaperBackground(cornerRadius: 26) }
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Keeper at the claw: \(viewModel.keeper.name), \(viewModel.keeper.perkTitle)")
            .accessibilityHint("Opens the lantern row")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(AccessibilityID.Vault.keeper)
        }
        .frame(maxWidth: unit * 1.3)
    }

    private func lift(unit: CGFloat) -> some View {
        VStack(spacing: -unit * 0.3) {
            ArtImage("item_lift")
                .frame(width: unit * 1.45)
                .overlay {
                    if viewModel.hasPlayed {
                        Text("Best \(Formatters.height(viewModel.bestHeight))")
                            .font(.display(14, relativeTo: .footnote))
                            .foregroundStyle(Theme.Colors.goldLight)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.7)))
                            .offset(y: -unit * 0.08)
                    }
                }
            Button(action: onPlay) {
                VStack(spacing: 2) {
                    Text("RIDE UP")
                    Text("Start a shift at the crater")
                        .font(.body(13, relativeTo: .caption, bold: true))
                        .tracking(0)
                        .foregroundStyle(Theme.Colors.paper.opacity(0.9))
                }
                .frame(maxWidth: 300)
            }
            .buttonStyle(CopperButtonStyle())
            .padding(.horizontal, 32)
            .accessibilityLabel("Ride up and start a shift")
            .accessibilityIdentifier(AccessibilityID.Vault.play)
        }
    }

    private func open(_ panel: VaultPanel) {
        viewModel.tapped()
        onOpen(panel)
    }
}

/// One clickable object standing in the vault, with a wooden name plaque under it.
private struct VaultObject: View {
    let art: String
    let title: String
    let hint: String
    let size: CGFloat
    let badge: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: -6) {
                ArtImage(art)
                    .frame(width: size, height: size * 0.86)
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Text("\(badge)")
                                .font(.display(13, relativeTo: .caption))
                                .foregroundStyle(Theme.Colors.ink)
                                .frame(minWidth: 24, minHeight: 24)
                                .background(Circle().fill(Theme.Colors.goldLight))
                                .overlay(Circle().strokeBorder(Theme.Colors.ink, lineWidth: 1.5))
                                .accessibilityHidden(true)
                        }
                    }
                VStack(spacing: 0) {
                    Text(title)
                        .font(.display(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.Colors.goldLight)
                    Text(hint)
                        .font(.body(12, relativeTo: .caption, bold: true))
                        .foregroundStyle(Theme.Colors.paper)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background { PlaqueBackground() }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(badge > 0 ? "\(badge) new" : "")
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
    }
}
