import Foundation
import Observation
import SwiftUI

/// Drives one shift at the crater: countdown, running, pause and the chalk slate.
/// Bridges the SpriteKit scene to SwiftUI state.
@MainActor
@Observable
final class GameViewModel: Identifiable {
    enum Phase: Equatable {
        case ready
        case countdown(Int)
        case running
        case paused
        case finished(RunOutcome)
    }

    /// A short callout shown under the HUD after notable moments.
    struct Callout: Equatable {
        enum Style { case weld, mint, steady, warning }
        let id = UUID()
        let text: String
        let style: Style
    }

    let id = UUID()
    private(set) var phase: Phase = .ready
    private(set) var hud: GameHUDState
    /// Created lazily in `prepareScene()` so presenting the view is cheap.
    private(set) var scene: HoardScene?
    /// Changes whenever a fresh scene is created so SwiftUI rebuilds the `SpriteView`.
    private(set) var sceneID = UUID()
    private(set) var callout: Callout?
    /// Incremented on every spill so the view can flash.
    private(set) var spillFlashCount = 0

    private let profileStore: ProfileStore
    private let haptics: HapticsService
    private let sound: SoundService
    private let usesAutopilot: Bool
    private let seedSource: () -> UInt64
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var calloutTask: Task<Void, Never>?

    var keeper: Keeper { profileStore.loadout.keeper }
    var loadout: Loadout { profileStore.loadout }
    var bestScore: Int { profileStore.profile.bestScore }
    var bestHeight: Int { profileStore.profile.bestHeight }

    var isScenePaused: Bool { phase == .paused }
    var isRunning: Bool { phase == .running }

    init(
        profileStore: ProfileStore,
        haptics: HapticsService,
        sound: SoundService,
        usesAutopilot: Bool = false,
        seedSource: @escaping () -> UInt64 = { UInt64.random(in: 1...UInt64.max) }
    ) {
        self.profileStore = profileStore
        self.haptics = haptics
        self.sound = sound
        self.usesAutopilot = usesAutopilot
        self.seedSource = seedSource
        hud = GameHUDState(loadout: profileStore.loadout)
    }

    // MARK: - Scene management

    /// Builds the scene if it does not exist yet. Safe to call repeatedly.
    func prepareScene() {
        guard scene == nil else { return }
        installScene()
    }

    private func installScene() {
        scene?.gameDelegate = nil
        let loadout = profileStore.loadout
        hud = GameHUDState(loadout: loadout)
        let newScene = HoardScene(size: CGSize(width: 402, height: 874), loadout: loadout, seed: seedSource(), autopilot: usesAutopilot)
        newScene.gameDelegate = self
        scene = newScene
        sceneID = UUID()
    }

    // MARK: - Intents

    /// Starts the 3-2-1 countdown and then the shift.
    func beginRun() {
        guard phase == .ready else { return }
        prepareScene()
        haptics.prepare()
        sound.updateAmbience(playing: true)
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            for value in stride(from: 3, through: 1, by: -1) {
                guard let self, !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.3)) { self.phase = .countdown(value) }
                self.haptics.impact(.light)
                self.sound.play(.count, volume: 0.6)
                try? await Task.sleep(for: .milliseconds(700))
            }
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.phase = .running }
            self.sound.play(.go, volume: 0.7)
            self.scene?.startRun()
        }
    }

    func pause() {
        guard phase == .running else { return }
        scene?.setSuspended(true)
        withAnimation(.easeOut(duration: 0.2)) { phase = .paused }
        haptics.selection()
    }

    func resume() {
        guard phase == .paused else { return }
        scene?.setSuspended(false)
        withAnimation(.easeOut(duration: 0.2)) { phase = .running }
        haptics.selection()
    }

    /// Pauses automatically when the app leaves the foreground mid-shift.
    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        guard scenePhase != .active else { return }
        if case .countdown = phase {
            countdownTask?.cancel()
            phase = .ready
        } else {
            pause()
        }
    }

    /// Creates a fresh scene with the latest upgrades and returns to the ready state.
    func restart() {
        countdownTask?.cancel()
        callout = nil
        installScene()
        withAnimation(.easeOut(duration: 0.25)) { phase = .ready }
    }

    /// Releases the scene when the game screen goes away.
    func tearDown() {
        countdownTask?.cancel()
        calloutTask?.cancel()
        sound.updateAmbience(playing: false)
        scene?.gameDelegate = nil
        scene = nil
    }

    private func show(_ text: String, style: Callout.Style) {
        let next = Callout(text: text, style: style)
        withAnimation(.spring(duration: 0.3)) { callout = next }
        calloutTask?.cancel()
        calloutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard let self, !Task.isCancelled, self.callout == next else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.callout = nil }
        }
    }
}

// MARK: - HoardSceneDelegate

extension GameViewModel: HoardSceneDelegate {
    func scene(_ scene: HoardScene, didUpdate hud: GameHUDState) {
        guard scene === self.scene, self.hud != hud else { return }
        self.hud = hud
    }

    func sceneDidDropCoin(_ scene: HoardScene, canWeld: Bool) {
        guard scene === self.scene else { return }
        sound.play(.drop, volume: 0.5)
    }

    func scene(_ scene: HoardScene, didRegister event: SessionEvent) {
        guard scene === self.scene else { return }
        switch event {
        case .landed(let id, let welded, _):
            if welded {
                sound.play(.weld, volume: 0.7)
                haptics.impact(.medium)
            } else {
                sound.playClink(id)
                haptics.impact(.light)
            }
        case .minted(let mint):
            sound.play(.mint)
            haptics.notify(.success)
            show("\(mint.metal.title) ingot minted · lava cools", style: .mint)
        case .steadyRaised(let value):
            if value >= hud.multiplierCap {
                sound.play(.steady, volume: 0.6)
                show("Dead level · \(Formatters.multiplier(value))", style: .steady)
            }
        case .steadyLost:
            sound.play(.tilt, volume: 0.6)
            haptics.notify(.warning)
            show("Beam tipped · steady bonus lost", style: .warning)
        case .spilled:
            spillFlashCount += 1
            sound.play(.spill, volume: 0.8)
            haptics.notify(.error)
        case .lavaRose(let level):
            let left = hud.lavaCapacity - level
            if left == 1 {
                show("Lava one notch from the beam!", style: .warning)
            }
        case .newCoin, .autoDrop, .lavaCooled, .finished:
            break
        }
    }

    func scene(_ scene: HoardScene, didFinishWith summary: RunSummary) {
        guard scene === self.scene else { return }
        let outcome = profileStore.recordRun(summary)
        sound.play(.gameOver, volume: 0.7)
        sound.updateAmbience(playing: false)
        withAnimation(.spring(duration: 0.45)) { phase = .finished(outcome) }
        if outcome.isNewBestScore { haptics.notify(.success) }
    }
}
