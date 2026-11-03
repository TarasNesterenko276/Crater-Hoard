import SpriteKit
import SwiftUI

/// Full-screen shift: SpriteKit crater shaft underneath, SwiftUI HUD and overlays on top.
struct GameView: View {
    @State private var viewModel: GameViewModel
    /// Called when the player leaves. A panel means "open this vault room next".
    let onExit: (VaultPanel?) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var hitFlash: Double = 0

    init(viewModel: GameViewModel, onExit: @escaping (VaultPanel?) -> Void) {
        self.viewModel = viewModel
        self.onExit = onExit
    }

    var body: some View {
        ZStack {
            Theme.Colors.basalt.ignoresSafeArea()

            if let scene = viewModel.scene {
                SpriteView(scene: scene, isPaused: viewModel.isScenePaused, preferredFramesPerSecond: 60)
                    .id(viewModel.sceneID)
                    .ignoresSafeArea()
                    .accessibilityLabel("Volcano slope. Drag to roll the cart, swipe up or down to change rails, tap to dash.")
            }

            RadialGradient(colors: [.clear, Theme.Colors.lava.opacity(0.6)], center: .center, startRadius: 140, endRadius: 560)
                .ignoresSafeArea()
                .opacity(hitFlash)
                .allowsHitTesting(false)

            GameHUDView(
                hud: viewModel.hud,
                callout: viewModel.callout,
                isVisible: viewModel.isRunning || viewModel.isScenePaused,
                onPause: viewModel.pause,
                onSwitch: viewModel.switchRail,
                onDash: viewModel.dash
            )

            overlays
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Game.screen)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { viewModel.prepareScene() }
        .onDisappear { viewModel.tearDown() }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhaseChange(newPhase)
        }
        .onChange(of: viewModel.hitFlashCount) { _, _ in
            hitFlash = 1
            withAnimation(.easeOut(duration: 0.7)) { hitFlash = 0 }
        }
    }

    @ViewBuilder
    private var overlays: some View {
        switch viewModel.phase {
        case .ready:
            ShiftBriefingOverlay(
                keeper: viewModel.keeper,
                loadout: viewModel.loadout,
                bestBank: viewModel.bestBank,
                bestScore: viewModel.bestScore,
                onStart: viewModel.beginRun,
                onLeave: { onExit(nil) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .countdown(let value):
            CountdownOverlay(value: value)
                .transition(.opacity)
        case .running:
            EmptyView()
        case .paused:
            PauseOverlay(
                hud: viewModel.hud,
                onResume: viewModel.resume,
                onRestart: viewModel.restart,
                onQuit: { onExit(nil) }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        case .finished(let outcome):
            ChalkSlateOverlay(
                outcome: outcome,
                keeper: viewModel.keeper,
                onAgain: viewModel.restart,
                onAssay: { onExit(.assay) },
                onVault: { onExit(nil) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
