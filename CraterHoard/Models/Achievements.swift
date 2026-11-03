import Foundation

/// Value snapshot of lifetime statistics used to evaluate achievements.
struct PlayerStats: Equatable, Sendable {
    var bestScore = 0
    var bestBank = 0
    var longestShift: Double = 0
    var totalRuns = 0
    var totalGoldEarned = 0
    var totalCoinsCaught = 0
    var totalCores = 0
    var totalBouldersBroken = 0
    var totalLightning = 0
    var hiredKeeperCount = 1
    var maxedUpgradeCount = 0
}

/// A crystal in the geode, grown by reaching a milestone.
struct Achievement: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    /// Index of the crystal artwork (`crystal_<n>`).
    let crystal: Int
    let isUnlocked: Bool
    /// Progress in `0...1` toward unlocking.
    let progress: Double

    var art: String { isUnlocked ? "crystal_\(crystal)" : "crystal_locked" }
}

/// Defines and evaluates all achievements. Evaluation is pure so it can be tested.
enum AchievementCatalog {
    private struct Definition {
        let id: String
        let title: String
        let detail: String
        let target: Double
        let value: @Sendable (PlayerStats) -> Double
    }

    private static let definitions: [Definition] = [
        Definition(id: "firstShift", title: "First Shift", detail: "Finish your first shift on the slope.", target: 1) { Double($0.totalRuns) },
        Definition(id: "bank100", title: "Full Cart", detail: "Bank 100 gold in a single trip.", target: 100) { Double($0.bestBank) },
        Definition(id: "bank300", title: "Mother Lode", detail: "Bank 300 gold in a single trip.", target: 300) { Double($0.bestBank) },
        Definition(id: "shift120", title: "Ash-Proof", detail: "Survive two minutes in one shift.", target: 120) { $0.longestShift },
        Definition(id: "coins250", title: "Coin Catcher", detail: "Catch 250 coins in total.", target: 250) { Double($0.totalCoinsCaught) },
        Definition(id: "cores10", title: "Heart of the Volcano", detail: "Catch 10 volcanic cores on the upper rail.", target: 10) { Double($0.totalCores) },
        Definition(id: "boulders25", title: "Rock Breaker", detail: "Break 25 obsidian boulders.", target: 25) { Double($0.totalBouldersBroken) },
        Definition(id: "lightning10", title: "Storm Rider", detail: "Catch 10 lightning strikes in the ash cloud.", target: 10) { Double($0.totalLightning) },
        Definition(id: "gold5000", title: "Deep Vault", detail: "Earn 5,000 gold in total.", target: 5_000) { Double($0.totalGoldEarned) },
        Definition(id: "keepers3", title: "Full Lantern Row", detail: "Hire 3 keepers.", target: 3) { Double($0.hiredKeeperCount) },
        Definition(id: "maxUpgrade", title: "Master Assayer", detail: "Fill any assay jar to the brim.", target: 1) { Double($0.maxedUpgradeCount) }
    ]

    static var count: Int { definitions.count }

    static func evaluate(_ stats: PlayerStats) -> [Achievement] {
        definitions.enumerated().map { index, definition in
            let value = definition.value(stats)
            return Achievement(
                id: definition.id,
                title: definition.title,
                detail: definition.detail,
                crystal: index % 6,
                isUnlocked: value >= definition.target,
                progress: min(max(value / definition.target, 0), 1)
            )
        }
    }
}
