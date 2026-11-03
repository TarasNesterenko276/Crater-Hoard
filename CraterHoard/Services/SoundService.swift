import AVFoundation
import Foundation

/// Generated sound effects (see `Artwork/generate_sounds.swift`).
enum SoundEffect: String, CaseIterable {
    case drop = "sfx_drop"
    case clink0 = "sfx_clink_0"
    case clink1 = "sfx_clink_1"
    case clink2 = "sfx_clink_2"
    case thud = "sfx_thud"
    case weld = "sfx_weld"
    case mint = "sfx_mint"
    case spill = "sfx_spill"
    case steady = "sfx_steady"
    case tilt = "sfx_tilt"
    case count = "sfx_count"
    case go = "sfx_go"
    case tap = "sfx_tap"
    case buy = "sfx_buy"
    case gameOver = "sfx_gameover"

    /// How many copies may overlap.
    var voices: Int {
        switch self {
        case .clink0, .clink1, .clink2, .drop: 3
        default: 2
        }
    }
}

/// Plays effects and the cave ambience while respecting the Sound setting.
/// Uses the ambient session so the game mixes with other audio and honours the silent switch.
@MainActor
final class SoundService {
    private var pools: [SoundEffect: [AVAudioPlayer]] = [:]
    private var nextVoice: [SoundEffect: Int] = [:]
    private var ambience: AVAudioPlayer?
    private let isEnabled: () -> Bool
    private var isPrepared = false

    /// A service that never plays anything (tests and UI-test runs).
    static let silent = SoundService { false }

    init(isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
    }

    private func prepareIfNeeded() {
        guard !isPrepared else { return }
        isPrepared = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for effect in SoundEffect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else { continue }
            pools[effect] = (0..<effect.voices).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                return player
            }
        }
    }

    func play(_ effect: SoundEffect, volume: Float = 1) {
        guard isEnabled() else { return }
        prepareIfNeeded()
        guard let pool = pools[effect], !pool.isEmpty else { return }
        let index = (nextVoice[effect] ?? 0) % pool.count
        nextVoice[effect] = index + 1
        let player = pool[index]
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    /// Coins ring at a slightly different pitch each time they land.
    func playClink(_ variant: Int) {
        let options: [SoundEffect] = [.clink0, .clink1, .clink2]
        play(options[abs(variant) % options.count], volume: 0.8)
    }

    /// Starts (or stops, when sound is off) the low lava rumble loop.
    func updateAmbience(playing: Bool) {
        guard playing, isEnabled() else {
            ambience?.setVolume(0, fadeDuration: 0.4)
            ambience?.pause()
            return
        }
        prepareIfNeeded()
        if ambience == nil, let url = Bundle.main.url(forResource: "ambience_cave", withExtension: "wav") {
            ambience = try? AVAudioPlayer(contentsOf: url)
            ambience?.numberOfLoops = -1
            ambience?.volume = 0
        }
        guard let ambience, !ambience.isPlaying else { return }
        ambience.play()
        ambience.setVolume(0.45, fadeDuration: 1)
    }
}
