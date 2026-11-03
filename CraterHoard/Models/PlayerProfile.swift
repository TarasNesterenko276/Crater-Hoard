import Foundation
import SwiftData

/// The single persistent player profile: gold, upgrades, keepers and lifetime stats.
@Model
final class PlayerProfile {
    var gold: Int
    var bestScore: Int
    var bestHeight: Int
    var totalRuns: Int
    var totalGoldEarned: Int
    var totalCoinsLanded: Int
    var totalMints: Int
    var totalWelds: Int
    var totalSpills: Int
    var bestMultiplier: Double

    var bellowsLevel: Int
    var counterweightLevel: Int
    var lavaSinkLevel: Int
    var assayLensLevel: Int
    var spiritLevelLevel: Int

    var hiredKeeperIDs: [String]
    var selectedKeeperID: String
    var createdAt: Date

    init(
        gold: Int = 0,
        hiredKeeperIDs: [String] = [Keeper.starter.rawValue],
        selectedKeeperID: String = Keeper.starter.rawValue,
        createdAt: Date = .now
    ) {
        self.gold = gold
        bestScore = 0
        bestHeight = 0
        totalRuns = 0
        totalGoldEarned = 0
        totalCoinsLanded = 0
        totalMints = 0
        totalWelds = 0
        totalSpills = 0
        bestMultiplier = 1
        bellowsLevel = 0
        counterweightLevel = 0
        lavaSinkLevel = 0
        assayLensLevel = 0
        spiritLevelLevel = 0
        self.hiredKeeperIDs = hiredKeeperIDs
        self.selectedKeeperID = selectedKeeperID
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
        case .bellows: bellowsLevel
        case .counterweight: counterweightLevel
        case .lavaSink: lavaSinkLevel
        case .assayLens: assayLensLevel
        case .spiritLevel: spiritLevelLevel
        }
    }

    func setLevel(_ level: Int, for kind: UpgradeKind) {
        switch kind {
        case .bellows: bellowsLevel = level
        case .counterweight: counterweightLevel = level
        case .lavaSink: lavaSinkLevel = level
        case .assayLens: assayLensLevel = level
        case .spiritLevel: spiritLevelLevel = level
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
            bestHeight: bestHeight,
            totalRuns: totalRuns,
            totalGoldEarned: totalGoldEarned,
            totalCoinsLanded: totalCoinsLanded,
            totalMints: totalMints,
            totalWelds: totalWelds,
            bestMultiplier: bestMultiplier,
            hiredKeeperCount: Keeper.allCases.filter { isHired($0) }.count,
            maxedUpgradeCount: UpgradeKind.allCases.filter { level(for: $0) >= $0.maxLevel }.count
        )
    }
}
