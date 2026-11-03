import Foundation
import Observation

/// Preferences and progress reset in the valve room.
@MainActor
@Observable
final class SettingsViewModel {
    private let profileStore: ProfileStore
    private let settings: SettingsStore
    private let haptics: HapticsService

    var isConfirmingReset = false
    var toastMessage: String?
    private(set) var toastIsError = false

    init(profileStore: ProfileStore, settings: SettingsStore, haptics: HapticsService) {
        self.profileStore = profileStore
        self.settings = settings
        self.haptics = haptics
    }

    var hapticsEnabled: Bool {
        get { settings.hapticsEnabled }
        set {
            settings.hapticsEnabled = newValue
            haptics.selection()
        }
    }

    var soundEnabled: Bool {
        get { settings.soundEnabled }
        set { settings.soundEnabled = newValue }
    }

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    func requestReset() {
        isConfirmingReset = true
    }

    func confirmReset() {
        do {
            try profileStore.resetProgress()
            settings.hasSeenGuide = false
            toastIsError = false
            toastMessage = "The vault is empty again. Fresh start!"
            haptics.notify(.warning)
        } catch {
            toastIsError = true
            toastMessage = "Could not reset: \(error.localizedDescription)"
            haptics.notify(.error)
        }
    }
}
