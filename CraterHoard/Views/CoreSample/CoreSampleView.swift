import SwiftUI

/// Records drilled out of the vault floor: every shift is a layer of rock whose thickness
/// is the height reached. Below it, lifetime stats and the geode of achievement crystals.
struct CoreSampleView: View {
    @State private var viewModel: CoreSampleViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(viewModel: CoreSampleViewModel) {
        self.viewModel = viewModel
    }

    private static let rockTones: [Color] = [
        Color(red: 0.55, green: 0.42, blue: 0.34), Color(red: 0.35, green: 0.27, blue: 0.25),
        Color(red: 0.72, green: 0.54, blue: 0.32), Color(red: 0.24, green: 0.19, blue: 0.21),
        Color(red: 0.62, green: 0.36, blue: 0.23), Color(red: 0.43, green: 0.42, blue: 0.40)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("Shift layers") { coreSample }
                section("Ledger") { statsGrid }
                section("Geode · \(viewModel.unlockedCount)/\(viewModel.achievements.count) crystals") { geode }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Core.screen)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.body(13, relativeTo: .caption, bold: true))
                .tracking(1.6)
                .foregroundStyle(Theme.Colors.copperDark)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    // MARK: - Core sample

    @ViewBuilder
    private var coreSample: some View {
        if viewModel.isEmpty {
            HStack(spacing: 14) {
                tubeCap
                    .frame(width: 74)
                    .overlay { Rectangle().fill(Color.black.opacity(0.12)).frame(width: 60, height: 70).offset(y: 40) }
                VStack(alignment: .leading, spacing: 4) {
                    Text("No layers yet")
                        .font(.display(18, relativeTo: .headline))
                        .foregroundStyle(Theme.Colors.ink)
                    Text("Ride up for a shift. Every shift you finish is drilled into this core as a new layer of rock.")
                        .font(.body(15))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.Core.empty)
        } else {
            VStack(spacing: 0) {
                tubeCap
                ForEach(viewModel.strata) { layer in
                    stratumRow(layer)
                }
                tubeCap.rotationEffect(.degrees(180))
            }
        }
    }

    private var tubeCap: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [Theme.Colors.copperLight, Theme.Colors.copperDark], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.black.opacity(0.7), lineWidth: 1))
                .frame(width: 74, height: 12)
            Spacer()
        }
        .accessibilityHidden(true)
    }

    private func stratumRow(_ layer: CoreSampleViewModel.Stratum) -> some View {
        let tone = Self.rockTones[layer.id % Self.rockTones.count]
        let height = 28 + 46 * layer.thickness
        return HStack(spacing: 14) {
            ZStack {
                Rectangle().fill(tone)
                Image("core_rock")
                    .resizable(resizingMode: .tile)
                    .accessibilityHidden(true)
                if layer.lightning > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(layer.lightning, 4), id: \.self) { _ in
                            Capsule().fill(Theme.Colors.goldLight).frame(width: 8, height: 4)
                        }
                    }
                }
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 6).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 6)
            }
            .frame(width: 60, height: height)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.35)).frame(height: 1) }
            .overlay { Rectangle().strokeBorder(Color.black.opacity(0.6), lineWidth: 1) }
            .padding(.horizontal, 7)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("\(Formatters.integer(layer.score)) pts")
                        .font(.display(17, relativeTo: .headline))
                        .foregroundStyle(Theme.Colors.ink)
                    if layer.isBest {
                        Text("BEST")
                            .font(.body(10, relativeTo: .caption2, bold: true))
                            .tracking(1)
                            .foregroundStyle(Theme.Colors.ink)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.Colors.goldLight))
                    }
                }
                Text("\(Formatters.integer(layer.gold)) gold · \(Formatters.duration(layer.duration)) · \(layer.keeper.name)")
                    .font(.body(13, relativeTo: .caption))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(Formatters.runDate(layer.date))
                    .font(.body(12, relativeTo: .caption2))
                    .foregroundStyle(Theme.Colors.inkSoft.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stats

    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: sizeClass == .regular ? 2 : 2), spacing: 10) {
            ForEach(viewModel.stats) { stat in
                HStack(spacing: 10) {
                    ArtImage(stat.art)
                        .frame(width: 34, height: 34)
                        .padding(4)
                        .background(Circle().fill(Theme.Colors.charcoal))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(stat.value)
                            .font(.display(17, relativeTo: .headline))
                            .foregroundStyle(Theme.Colors.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(stat.title)
                            .font(.body(12, relativeTo: .caption))
                            .foregroundStyle(Theme.Colors.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Colors.paperShade.opacity(0.45)))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(stat.id == "bestScore" ? AccessibilityID.Core.bestScore : "core.stat.\(stat.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Core.stats)
    }

    // MARK: - Geode

    private var geode: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                ForEach(viewModel.achievements) { achievement in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            viewModel.selectedAchievement = viewModel.selectedAchievement == achievement ? nil : achievement
                        }
                    } label: {
                        VStack(spacing: 2) {
                            ArtImage(achievement.art)
                                .frame(width: 54, height: 54)
                            Text(achievement.title)
                                .font(.body(11, relativeTo: .caption2, bold: true))
                                .foregroundStyle(Theme.Colors.chalk)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 12).fill(viewModel.selectedAchievement == achievement ? Color.white.opacity(0.12) : .clear))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(achievement.title)
                    .accessibilityValue(achievement.isUnlocked ? "Grown" : "\(Formatters.percent(achievement.progress)) grown")
                    .accessibilityHint(achievement.detail)
                }
            }
            if let selected = viewModel.selectedAchievement {
                VStack(spacing: 6) {
                    Text(selected.title)
                        .font(.display(16, relativeTo: .headline))
                        .foregroundStyle(Theme.Colors.goldLight)
                    Text(selected.detail)
                        .font(.body(14))
                        .foregroundStyle(Theme.Colors.chalk)
                        .multilineTextAlignment(.center)
                    ProgressView(value: selected.progress)
                        .tint(Theme.Colors.patina)
                        .accessibilityLabel("Progress")
                }
                .padding(.horizontal, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("Tap a crystal to see how it grows.")
                    .font(.body(13, relativeTo: .caption))
                    .foregroundStyle(Theme.Colors.chalk.opacity(0.8))
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ImagePaint(image: Image("tex_slate"), scale: 1))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.Colors.rockBorder, lineWidth: 4))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Core.geode)
    }
}

private extension Theme.Colors {
    static let rockBorder = Color(red: 0.30, green: 0.24, blue: 0.24)
}
