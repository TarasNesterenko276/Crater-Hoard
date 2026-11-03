import Foundation
import Observation

/// Browsing, hiring and choosing keepers on the lantern row.
@MainActor
@Observable
final class LanternsViewModel {
    private let profileStore: ProfileStore
    private let haptics: HapticsService
    private let sound: SoundService

    /// The keeper currently lit up in the row (not necessarily the one in the cart).
    var focused: Keeper
    var toastMessage: String?
    private(set) var toastIsError = false

    init(profileStore: ProfileStore, haptics: HapticsService, sound: SoundService) {
        self.profileStore = profileStore
        self.haptics = haptics
        self.sound = sound
        focused = profileStore.loadout.keeper
    }

    enum Action: Equatable {
        case hire(price: Int)
        case select
        case inTheCart
    }

    var gold: Int { profileStore.gold }
    var selected: Keeper { profileStore.loadout.keeper }

    func isHired(_ keeper: Keeper) -> Bool { profileStore.profile.isHired(keeper) }

    func action(for keeper: Keeper) -> Action {
        if keeper == selected { return .inTheCart }
        return isHired(keeper) ? .select : .hire(price: keeper.price)
    }

    func focus(_ keeper: Keeper) {
        guard keeper != focused else { return }
        focused = keeper
        haptics.selection()
        sound.play(.tap, volume: 0.5)
    }

    func performAction() {
        let keeper = focused
        do {
            switch action(for: keeper) {
            case .hire:
                try profileStore.hireKeeper(keeper)
                toastMessage = "\(keeper.name) joined the vault and took the cart."
                sound.play(.buy, volume: 0.7)
            case .select:
                try profileStore.selectKeeper(keeper)
                toastMessage = "\(keeper.name) is in the cart."
                sound.play(.tap, volume: 0.6)
            case .inTheCart:
                return
            }
            toastIsError = false
            haptics.notify(.success)
        } catch {
            toastIsError = true
            toastMessage = error.localizedDescription
            haptics.notify(.error)
        }
    }
}
