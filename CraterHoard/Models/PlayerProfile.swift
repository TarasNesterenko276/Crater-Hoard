import Foundation
import SwiftData

/// The single persistent player profile: gold, upgrades, keepers and lifetime stats.
@Model
final class PlayerProfile {
    var gold: Int = 0
    var bestScore: Int = 0
    var bestBank: Int = 0
    var longestShift: Double = 0
    var totalRuns: Int = 0
    var totalGoldEarned: Int = 0
    var totalCoinsCaught: Int = 0
    var totalCores: Int = 0
    var totalBanks: Int = 0
    var totalBouldersBroken: Int = 0
    var totalLightning: Int = 0

    var wheelsLevel: Int = 0
    var waterTankLevel: Int = 0
    var ironPlatingLevel: Int = 0
    var railSwitchLevel: Int = 0
    var sieveLevel: Int = 0

    var hiredKeeperIDs: [String] = [Keeper.starter.rawValue]
    var selectedKeeperID: String = Keeper.starter.rawValue
    var createdAt: Date = Date.now

    init(gold: Int = 0, createdAt: Date = .now) {
        self.gold = gold
        self.createdAt = createdAt
    }

    // MARK: - Derived values

    var selectedKeeper: Keeper {
        Keeper(rawValue: selectedKeeperID) ?? .starter
    }

    func isHired(_ keeper: Keeper) -> Bool {
        keeper.price == 0 || hiredKeeperIDs.contains(keeper.rawValue)
    }

    func level(for kind: UpgradeKind) -> Int {
        switch kind {
        case .wheels: wheelsLevel
        case .waterTank: waterTankLevel
        case .ironPlating: ironPlatingLevel
        case .railSwitch: railSwitchLevel
        case .sieve: sieveLevel
        }
    }

    func setLevel(_ level: Int, for kind: UpgradeKind) {
        switch kind {
        case .wheels: wheelsLevel = level
        case .waterTank: waterTankLevel = level
        case .ironPlating: ironPlatingLevel = level
        case .railSwitch: railSwitchLevel = level
        case .sieve: sieveLevel = level
        }
    }

    /// The gameplay numbers the current keeper and upgrades produce.
    var loadout: Loadout {
        var loadout = Loadout(keeper: selectedKeeper)
        for kind in UpgradeKind.allCases {
            loadout.setLevel(level(for: kind), for: kind)
        }
        return loadout
    }

    /// Lightweight value snapshot used for achievement evaluation.
    var statsSnapshot: PlayerStats {
        PlayerStats(
            bestScore: bestScore,
            bestBank: bestBank,
            longestShift: longestShift,
            totalRuns: totalRuns,
            totalGoldEarned: totalGoldEarned,
            totalCoinsCaught: totalCoinsCaught,
            totalCores: totalCores,
            totalBouldersBroken: totalBouldersBroken,
            totalLightning: totalLightning,
            hiredKeeperCount: Keeper.allCases.filter { isHired($0) }.count,
            maxedUpgradeCount: UpgradeKind.allCases.filter { level(for: $0) >= $0.maxLevel }.count
        )
    }
}
