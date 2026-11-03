import Foundation
import Observation

/// Records: the core sample of past shifts, lifetime stats and the achievement geode.
@MainActor
@Observable
final class CoreSampleViewModel {
    struct Stratum: Identifiable, Equatable {
        let id: Int
        let date: Date
        let heightCentimetres: Int
        let score: Int
        let gold: Int
        let mints: Int
        let keeper: Keeper
        /// Relative thickness in `0.15...1` compared with the tallest shift on record.
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
        let tallest = max(1, runs.map(\.heightCentimetres).max() ?? 1)
        let best = profileStore.profile.bestScore
        return runs.enumerated().map { index, run in
            Stratum(
                id: index,
                date: run.date,
                heightCentimetres: run.heightCentimetres,
                score: run.score,
                gold: run.gold,
                mints: run.mints,
                keeper: run.keeper,
                thickness: max(0.15, Double(run.heightCentimetres) / Double(tallest)),
                isBest: run.score == best && best > 0
            )
        }
    }

    var stats: [Stat] {
        let profile = profileStore.profile
        return [
            Stat(id: "bestHeight", title: "Tallest hoard", value: Formatters.height(profile.bestHeight), art: "hud_ruler"),
            Stat(id: "bestScore", title: "Best score", value: Formatters.integer(profile.bestScore), art: "mine_cart"),
            Stat(id: "runs", title: "Shifts worked", value: Formatters.integer(profile.totalRuns), art: "item_lift"),
            Stat(id: "gold", title: "Gold earned", value: Formatters.integer(profile.totalGoldEarned), art: "icon_gold"),
            Stat(id: "mints", title: "Ingots minted", value: Formatters.integer(profile.totalMints), art: "ingot_gold"),
            Stat(id: "welds", title: "Coins welded", value: Formatters.integer(profile.totalWelds), art: "coin_copper"),
            Stat(id: "spills", title: "Coins spilled", value: Formatters.integer(profile.totalSpills), art: "lava_crust"),
            Stat(id: "steady", title: "Best steady", value: Formatters.multiplier(profile.bestMultiplier), art: "hud_dial")
        ]
    }

    var achievements: [Achievement] { profileStore.achievements }
    var unlockedCount: Int { achievements.filter(\.isUnlocked).count }
}
