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
    private(set) var scene: SlopeScene?
    /// Changes whenever a fresh scene is created so SwiftUI rebuilds the `SpriteView`.
    private(set) var sceneID = UUID()
    private(set) var callout: Callout?
    /// Incremented on every bomb hit or overheat so the view can flash.
    private(set) var hitFlashCount = 0
    @ObservationIgnored private var sawLightning = false

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
    var bestBank: Int { profileStore.profile.bestBank }

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
        // The autopilot always plays the same shift so UI tests and screenshot tours are repeatable.
        let seed = usesAutopilot ? 1215 : seedSource()
        let newScene = SlopeScene(size: CGSize(width: 402, height: 874), loadout: loadout, seed: seed, autopilot: usesAutopilot)
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

    /// On-screen alternatives to the tap and swipe gestures.
    func dash() {
        guard phase == .running else { return }
        scene?.dash()
    }

    func switchRail() {
        guard phase == .running else { return }
        scene?.switchRail()
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
        sawLightning = false
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

// MARK: - SlopeSceneDelegate

extension GameViewModel: SlopeSceneDelegate {
    func scene(_ scene: SlopeScene, didUpdate hud: GameHUDState) {
        guard scene === self.scene, self.hud != hud else { return }
        self.hud = hud
    }

    func scene(_ scene: SlopeScene, didRegister event: SessionEvent) {
        guard scene === self.scene else { return }
        switch event {
        case .volleyWarning(let kind):
            sound.play(.thud, volume: kind == .coins ? 0.35 : 0.7)
            if kind == .bombs { haptics.impact(.light) }
        case .caught(let projectile, _):
            sound.playClink(projectile.id)
            haptics.impact(.light)
            if projectile.payload == .core { show("Volcanic core!", style: .mint) }
        case .bombHit(_, let lost):
            hitFlashCount += 1
            sound.play(.spill, volume: 0.9)
            haptics.notify(.error)
            show(lost > 0 ? "Bomb hit! \(lost) coins knocked out" : "Bomb hit! A plank cracked", style: .warning)
        case .boulderFormed:
            sound.play(.thud, volume: 0.5)
        case .boulderBroken:
            sound.play(.clink2, volume: 0.8)
            haptics.impact(.medium)
        case .blocked:
            haptics.impact(.light)
            show("Boulder ahead: tap to dash through", style: .warning)
        case .banked(let gold, let coins, _):
            sound.play(.mint)
            haptics.notify(.success)
            show("Banked \(coins) coins: +\(gold) gold", style: .mint)
        case .overheated(let lost):
            hitFlashCount += 1
            sound.play(.tilt)
            haptics.notify(.error)
            show(lost > 0 ? "Overheated! \(lost) coins melted" : "Overheated! A plank cracked", style: .warning)
        case .switchStarted:
            sound.play(.drop, volume: 0.5)
            haptics.selection()
        case .dashed:
            sound.play(.drop, volume: 0.6)
            haptics.impact(.medium)
        case .lightningWarning:
            if !sawLightning {
                sawLightning = true
                show("Lightning in the ash! Stand under the mark", style: .steady)
            }
        case .lightningCaught(_, let gold):
            sound.play(.weld)
            haptics.notify(.success)
            show("Storm caught: +\(gold) gold, bigger bank", style: .steady)
        case .lightningMissed:
            sound.play(.weld, volume: 0.4)
        case .launched, .missed, .boulderCrumbled, .switchFinished, .finished:
            break
        }
    }

    func scene(_ scene: SlopeScene, didFinishWith summary: RunSummary) {
        guard scene === self.scene else { return }
        let outcome = profileStore.recordRun(summary)
        sound.play(.gameOver, volume: 0.7)
        sound.updateAmbience(playing: false)
        withAnimation(.spring(duration: 0.45)) { phase = .finished(outcome) }
        if outcome.isNewBestScore { haptics.notify(.success) }
    }
}
