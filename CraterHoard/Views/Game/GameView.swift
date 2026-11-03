import SpriteKit
import SwiftUI

/// Full-screen shift: SpriteKit crater shaft underneath, SwiftUI HUD and overlays on top.
struct GameView: View {
    @State private var viewModel: GameViewModel
    /// Called when the player leaves. A panel means "open this vault room next".
    let onExit: (VaultPanel?) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var spillFlash: Double = 0

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
                    .accessibilityLabel("Crater shaft. Drag to move the claw, lift your finger to drop the coin.")
            }

            RadialGradient(colors: [.clear, Theme.Colors.lava.opacity(0.6)], center: .center, startRadius: 140, endRadius: 560)
                .ignoresSafeArea()
                .opacity(spillFlash)
                .allowsHitTesting(false)

            GameHUDView(
                hud: viewModel.hud,
                bestHeight: viewModel.bestHeight,
                callout: viewModel.callout,
                isVisible: viewModel.isRunning || viewModel.isScenePaused,
                onPause: viewModel.pause
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
        .onChange(of: viewModel.spillFlashCount) { _, _ in
            spillFlash = 1
            withAnimation(.easeOut(duration: 0.7)) { spillFlash = 0 }
        }
    }

    @ViewBuilder
    private var overlays: some View {
        switch viewModel.phase {
        case .ready:
            ShiftBriefingOverlay(
                keeper: viewModel.keeper,
                loadout: viewModel.loadout,
                bestHeight: viewModel.bestHeight,
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
