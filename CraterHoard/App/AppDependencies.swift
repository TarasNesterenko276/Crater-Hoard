import Foundation
import SwiftData

/// Composition root: builds the stores and services the whole app shares.
@MainActor
final class AppDependencies {
    let container: ModelContainer
    let profileStore: ProfileStore
    let settings: SettingsStore
    let haptics: HapticsService
    let sound: SoundService
    let isUITesting: Bool
    /// The claw plays by itself (UI tests and screenshot tours cannot play in real time).
    let usesAutopilot: Bool

    static let uiTestingArgument = "--uitesting"
    static let autopilotArgument = "--autopilot"
    /// Starts a UI-test session with no gold, for empty-state and refusal checks.
    static let brokeArgument = "--broke"
    /// Seeds a few finished shifts so the records screen has history.
    static let historyArgument = "--history"
    /// Keeps the first-shift guide unread so its flow can be tested.
    static let showGuideArgument = "--show-guide"
    private static let uiTestingDefaultsSuite = "com.craterhoard.game41.uitesting"

    init(launchArguments: [String] = CommandLine.arguments) throws {
        isUITesting = launchArguments.contains(Self.uiTestingArgument)
        usesAutopilot = launchArguments.contains(Self.autopilotArgument)

        let defaults: UserDefaults
        if isUITesting, let suite = UserDefaults(suiteName: Self.uiTestingDefaultsSuite) {
            suite.removePersistentDomain(forName: Self.uiTestingDefaultsSuite)
            defaults = suite
        } else {
            defaults = .standard
        }

        container = try PersistenceController.makeContainer(inMemory: isUITesting)
        profileStore = try ProfileStore(container: container)
        settings = SettingsStore(defaults: defaults)

        let settings = self.settings
        haptics = HapticsService { settings.hapticsEnabled }
        sound = isUITesting ? .silent : SoundService { settings.soundEnabled }

        if isUITesting {
            // Deterministic state so UI tests can exercise purchases without playing.
            settings.hasSeenGuide = !launchArguments.contains(Self.showGuideArgument)
            if !launchArguments.contains(Self.brokeArgument) {
                try profileStore.grantGold(1_000)
            }
            if launchArguments.contains(Self.historyArgument) {
                Self.seedHistory(into: profileStore)
            }
        }
    }

    private static func seedHistory(into store: ProfileStore) {
        let shifts: [(Int, Int, Int, Int)] = [(64, 120, 1, 3), (118, 260, 3, 2), (92, 190, 2, 4), (171, 410, 5, 1), (140, 330, 4, 3)]
        for (height, gold, mints, spills) in shifts {
            store.recordRun(RunSummary(
                score: gold + height,
                gold: gold,
                heightCentimetres: height,
                coinsLanded: gold / 8,
                mints: mints,
                welds: mints * 2 + 1,
                spills: spills,
                bestMultiplier: 1.75,
                duration: 95,
                keeperID: Keeper.starter.rawValue
            ))
        }
        // Keep the seeded gold predictable for purchase tests.
        try? store.grantGold(-store.gold + 1_000)
    }
}
