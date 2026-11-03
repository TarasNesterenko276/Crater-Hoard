import SwiftUI

/// Hosts the vault, the hatch drawer with the current panel, and the full-screen shift.
struct RootView: View {
    let dependencies: AppDependencies

    @State private var panel: VaultPanel?
    /// When the guide is shown before the very first shift, finishing it starts the game.
    @State private var guideStartsShift = false
    @State private var game: GameViewModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VaultView(
                viewModel: VaultViewModel(profileStore: dependencies.profileStore, settings: dependencies.settings, sound: dependencies.sound),
                animatesEmbers: !reduceMotion && !dependencies.isUITesting && panel == nil && game == nil,
                onOpen: open,
                onPlay: startShift
            )

            if let panel {
                HatchDrawer(panel: panel, onClose: closePanel) {
                    panelContent(panel)
                }
                .zIndex(1)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.12), value: panel)
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $game) { model in
            GameView(viewModel: model) { destination in
                game = nil
                if let destination { open(destination) }
            }
        }
    }

    @ViewBuilder
    private func panelContent(_ panel: VaultPanel) -> some View {
        switch panel {
        case .assay:
            AssayShelfView(viewModel: AssayViewModel(profileStore: dependencies.profileStore, haptics: dependencies.haptics, sound: dependencies.sound))
        case .lanterns:
            LanternRowView(viewModel: LanternsViewModel(profileStore: dependencies.profileStore, haptics: dependencies.haptics, sound: dependencies.sound))
        case .core:
            CoreSampleView(viewModel: CoreSampleViewModel(profileStore: dependencies.profileStore))
        case .guide:
            NoticeBoardView(viewModel: GuideViewModel(settings: dependencies.settings, startsShiftWhenDone: guideStartsShift) { startShift in
                closePanel()
                if startShift { launchGame() }
            })
        case .settings:
            ValveRoomView(
                viewModel: SettingsViewModel(profileStore: dependencies.profileStore, settings: dependencies.settings, haptics: dependencies.haptics),
                onShowGuide: { open(.guide) }
            )
        }
    }

    private func open(_ next: VaultPanel) {
        guideStartsShift = false
        panel = next
    }

    private func closePanel() {
        guideStartsShift = false
        panel = nil
    }

    /// The first shift is preceded by the notice board so new players learn the rules.
    private func startShift() {
        if dependencies.settings.hasSeenGuide {
            launchGame()
        } else {
            panel = .guide
            guideStartsShift = true
        }
    }

    private func launchGame() {
        game = GameViewModel(
            profileStore: dependencies.profileStore,
            haptics: dependencies.haptics,
            sound: dependencies.sound,
            usesAutopilot: dependencies.usesAutopilot
        )
    }
}
