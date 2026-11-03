import Foundation

/// Value snapshot of lifetime statistics used to evaluate achievements.
struct PlayerStats: Equatable, Sendable {
    var bestScore = 0
    var bestHeight = 0
    var totalRuns = 0
    var totalGoldEarned = 0
    var totalCoinsLanded = 0
    var totalMints = 0
    var totalWelds = 0
    var bestMultiplier: Double = 1
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
        Definition(id: "firstShift", title: "First Shift", detail: "Finish your first shift at the crater.", target: 1) { Double($0.totalRuns) },
        Definition(id: "height100", title: "Knee High", detail: "Raise the hoard 100 cm in one shift.", target: 100) { Double($0.bestHeight) },
        Definition(id: "height250", title: "Crater Rim", detail: "Raise the hoard 250 cm in one shift.", target: 250) { Double($0.bestHeight) },
        Definition(id: "firstMint", title: "Fresh Mint", detail: "Mint your first ingot.", target: 1) { Double($0.totalMints) },
        Definition(id: "mints25", title: "Ingot Smith", detail: "Mint 25 ingots in total.", target: 25) { Double($0.totalMints) },
        Definition(id: "welds50", title: "Hot Hands", detail: "Weld 50 coins in total.", target: 50) { Double($0.totalWelds) },
        Definition(id: "steady", title: "Dead Level", detail: "Reach a x2 steady multiplier.", target: 2) { $0.bestMultiplier },
        Definition(id: "score1500", title: "Dragon's Share", detail: "Score 1,500 in a single shift.", target: 1_500) { Double($0.bestScore) },
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
