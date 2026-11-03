import Foundation
import Observation

/// Upgrade purchases on the assay shelf.
@MainActor
@Observable
final class AssayViewModel {
    private let profileStore: ProfileStore
    private let haptics: HapticsService
    private let sound: SoundService

    var toastMessage: String?
    private(set) var toastIsError = false
    /// The jar that just got a level, so it can bubble.
    private(set) var lastBrewed: UpgradeKind?

    init(profileStore: ProfileStore, haptics: HapticsService, sound: SoundService) {
        self.profileStore = profileStore
        self.haptics = haptics
        self.sound = sound
    }

    var gold: Int { profileStore.gold }

    func level(of kind: UpgradeKind) -> Int { profileStore.level(of: kind) }
    func nextCost(of kind: UpgradeKind) -> Int? { profileStore.nextCost(of: kind) }

    func canAfford(_ kind: UpgradeKind) -> Bool {
        nextCost(of: kind).map(profileStore.canAfford) ?? false
    }

    func currentEffect(of kind: UpgradeKind) -> String {
        kind.effectDescription(atLevel: level(of: kind))
    }

    func nextEffect(of kind: UpgradeKind) -> String? {
        let next = level(of: kind) + 1
        return next <= kind.maxLevel ? kind.effectDescription(atLevel: next) : nil
    }

    func buy(_ kind: UpgradeKind) {
        do {
            try profileStore.purchaseUpgrade(kind)
            lastBrewed = kind
            toastIsError = false
            toastMessage = "\(kind.title) brewed to level \(level(of: kind))."
            haptics.notify(.success)
            sound.play(.buy, volume: 0.7)
        } catch {
            toastIsError = true
            toastMessage = error.localizedDescription
            haptics.notify(.error)
        }
    }
}
