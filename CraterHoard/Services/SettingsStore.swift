import Foundation
import Observation

/// Player preferences backed by `UserDefaults`.
@MainActor
@Observable
final class SettingsStore {
    private enum Keys {
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let soundEnabled = "settings.soundEnabled"
        static let hasSeenGuide = "settings.hasSeenGuide"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
    }

    /// Whether the notice board has been read before the first shift.
    var hasSeenGuide: Bool {
        didSet { defaults.set(hasSeenGuide, forKey: Keys.hasSeenGuide) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        soundEnabled = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
        hasSeenGuide = defaults.bool(forKey: Keys.hasSeenGuide)
    }
}
