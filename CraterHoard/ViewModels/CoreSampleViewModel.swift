import Foundation
import Observation

/// Records: the core sample of past shifts, lifetime stats and the achievement geode.
@MainActor
@Observable
final class CoreSampleViewModel {
    struct Stratum: Identifiable, Equatable {
        let id: Int
        let date: Date
        let score: Int
        let gold: Int
        let duration: TimeInterval
        let lightning: Int
        let keeper: Keeper
        /// Relative thickness in `0.15...1` compared with the best shift on record.
        let thickness: Double
        let isBest: Bool
    }

    struct Stat: Identifiable, Equatable {
        let id: String
        let title: String
        let value: String
        let art: String
    }

    private let profileStore: ProfileStore
    var selectedAchievement: Achievement?

    init(profileStore: ProfileStore) {
        self.profileStore = profileStore
    }

    var isEmpty: Bool { profileStore.recentRuns.isEmpty }

    /// Most recent shift on top, like the newest layer of rock.
    var strata: [Stratum] {
        let runs = profileStore.recentRuns
        let top = max(1, runs.map(\.score).max() ?? 1)
        let best = profileStore.profile.bestScore
        return runs.enumerated().map { index, run in
            Stratum(
                id: index,
                date: run.date,
                score: run.score,
                gold: run.gold,
                duration: run.duration,
                lightning: run.lightningCaught,
                keeper: run.keeper,
                thickness: max(0.15, Double(run.score) / Double(top)),
                isBest: run.score == best && best > 0
            )
        }
    }

    var stats: [Stat] {
        let profile = profileStore.profile
        return [
            Stat(id: "bestScore", title: "Best score", value: Formatters.integer(profile.bestScore), art: "mine_cart"),
            Stat(id: "bestBank", title: "Best haul", value: Formatters.integer(profile.bestBank), art: "cart_cargo"),
            Stat(id: "runs", title: "Shifts worked", value: Formatters.integer(profile.totalRuns), art: "item_lift"),
            Stat(id: "gold", title: "Gold earned", value: Formatters.integer(profile.totalGoldEarned), art: "icon_gold"),
            Stat(id: "coins", title: "Coins caught", value: Formatters.integer(profile.totalCoinsCaught), art: "coin_front_gold"),
            Stat(id: "cores", title: "Volcanic cores", value: Formatters.integer(profile.totalCores), art: "volcanic_core"),
            Stat(id: "boulders", title: "Boulders broken", value: Formatters.integer(profile.totalBouldersBroken), art: "boulder"),
            Stat(id: "lightning", title: "Lightning caught", value: Formatters.integer(profile.totalLightning), art: "lightning_bolt")
        ]
    }

    var achievements: [Achievement] { profileStore.achievements }
    var unlockedCount: Int { achievements.filter(\.isUnlocked).count }
}
