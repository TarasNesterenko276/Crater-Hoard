import Foundation
import Observation

/// State for the vault hub: balance, selected keeper and records shown on the cave objects.
@MainActor
@Observable
final class VaultViewModel {
    private let profileStore: ProfileStore
    private let settings: SettingsStore
    private let sound: SoundService

    init(profileStore: ProfileStore, settings: SettingsStore, sound: SoundService) {
        self.profileStore = profileStore
        self.settings = settings
        self.sound = sound
    }

    var gold: Int { profileStore.gold }
    var keeper: Keeper { profileStore.loadout.keeper }
    var bestHeight: Int { profileStore.profile.bestHeight }
    var bestScore: Int { profileStore.profile.bestScore }
    var hasPlayed: Bool { profileStore.profile.totalRuns > 0 }
    var needsGuide: Bool { !settings.hasSeenGuide }
    var persistenceError: String? { profileStore.persistenceErrorMessage }

    var unlockedCrystals: Int { profileStore.achievements.filter(\.isUnlocked).count }

    /// Upgrades the player can afford right now, shown as a badge on the shelf.
    var affordableUpgrades: Int {
        UpgradeKind.allCases.filter { kind in
            profileStore.nextCost(of: kind).map(profileStore.canAfford) ?? false
        }.count
    }

    func tapped() {
        sound.play(.tap, volume: 0.6)
    }
}
