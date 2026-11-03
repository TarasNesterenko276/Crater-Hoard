import SwiftUI

/// Upgrades as glass jars on wooden shelves. Each level fills the jar with more melt.
struct AssayShelfView: View {
    @State private var viewModel: AssayViewModel

    init(viewModel: AssayViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                HStack {
                    Text("Brew upgrades with gold from your shifts. Each jar holds five levels.")
                        .font(.body(15))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    GoldBadge(amount: viewModel.gold)
                }
                .padding(.bottom, 8)

                ForEach(UpgradeKind.allCases) { kind in
                    JarShelfRow(
                        kind: kind,
                        level: viewModel.level(of: kind),
                        cost: viewModel.nextCost(of: kind),
                        canAfford: viewModel.canAfford(kind),
                        currentEffect: viewModel.currentEffect(of: kind),
                        nextEffect: viewModel.nextEffect(of: kind),
                        isBubbling: viewModel.lastBrewed == kind,
                        onBuy: { viewModel.buy(kind) }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .toast(message: $viewModel.toastMessage, isError: viewModel.toastIsError)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Assay.screen)
    }
}

private struct JarShelfRow: View {
    let kind: UpgradeKind
    let level: Int
    let cost: Int?
    let canAfford: Bool
    let currentEffect: String
    let nextEffect: String?
    let isBubbling: Bool
    let onBuy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 14) {
                MeltJar(kind: kind, fill: Double(level) / Double(kind.maxLevel), isBubbling: isBubbling)
                    .frame(width: 82, height: 102)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(kind.title)
                            .font(.display(19, relativeTo: .headline))
                            .foregroundStyle(Theme.Colors.ink)
                        Spacer(minLength: 4)
                        Text("Lv \(level)/\(kind.maxLevel)")
                            .font(.body(13, relativeTo: .caption, bold: true))
                            .foregroundStyle(Theme.Colors.copperDark)
                            .accessibilityIdentifier(AccessibilityID.Assay.level(kind))
                    }
                    Text(kind.summary)
                        .font(.body(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(currentEffect)
                        if let nextEffect {
                            Image(systemName: "arrow.right")
                                .font(.caption.bold())
                                .accessibilityLabel("then")
                            Text(nextEffect)
                                .foregroundStyle(Theme.Colors.patinaDark)
                        }
                    }
                    .font(.body(13, relativeTo: .caption, bold: true))
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                    buyButton
                        .padding(.top, 2)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 4)

            Image("shelf_plank")
                .resizable(capInsets: EdgeInsets(top: 0, leading: 40, bottom: 0, trailing: 40), resizingMode: .stretch)
                .frame(height: 22)
                .accessibilityHidden(true)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var buyButton: some View {
        if let cost {
            Button(action: onBuy) {
                HStack(spacing: 6) {
                    Text("Brew")
                    ArtImage("icon_gold").frame(width: 20, height: 20)
                    Text(Formatters.integer(cost))
                        .monospacedDigit()
                }
                .font(.display(16, relativeTo: .headline))
            }
            .buttonStyle(CopperButtonStyle(tint: canAfford ? Theme.Colors.copper : Color(white: 0.45), isProminent: false))
            .accessibilityLabel("Brew \(kind.title) for \(Formatters.integer(cost)) gold")
            .accessibilityIdentifier(AccessibilityID.Assay.buy(kind))
        } else {
            Label("Full jar", systemImage: "checkmark.seal.fill")
                .font(.display(15, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.patinaDark)
                .frame(minHeight: Theme.Metrics.minimumTap)
                .accessibilityIdentifier(AccessibilityID.Assay.buy(kind))
        }
    }
}

/// A glass jar with its melt level drawn behind the glass, clipped to the jar's interior.
private struct MeltJar: View {
    let kind: UpgradeKind
    let fill: Double
    let isBubbling: Bool

    @State private var bubble = false

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    LinearGradient(colors: [Theme.Colors.lavaHot, Theme.Colors.lava, Theme.Colors.copperDark], startPoint: .top, endPoint: .bottom)
                        .frame(height: proxy.size.height * (0.12 + 0.7 * fill))
                        .overlay(alignment: .top) {
                            Capsule().fill(Color.white.opacity(0.45)).frame(height: 3).padding(.horizontal, 8)
                        }
                }
            }
            .mask(ArtImage("jar_mask"))
            .opacity(fill > 0 ? 1 : 0.25)

            ArtImage(kind.jarArt)
        }
        .scaleEffect(bubble ? 1.06 : 1)
        .animation(.spring(duration: 0.5), value: fill)
        .onChange(of: fill) { _, _ in
            guard isBubbling else { return }
            withAnimation(.spring(duration: 0.25, bounce: 0.6)) { bubble = true }
            withAnimation(.spring(duration: 0.4).delay(0.25)) { bubble = false }
        }
        .accessibilityElement()
        .accessibilityLabel("\(kind.title) jar \(Formatters.percent(fill)) full")
    }
}
