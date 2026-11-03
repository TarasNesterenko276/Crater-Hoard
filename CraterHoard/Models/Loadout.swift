import Foundation

/// The gameplay numbers produced by the chosen keeper and the bought upgrades.
struct Loadout: Equatable, Sendable {
    var keeper: Keeper
    var bellows = 0
    var counterweight = 0
    var lavaSink = 0
    var assayLens = 0
    var spiritLevel = 0

    static let starter = Loadout(keeper: .starter)

    func level(for kind: UpgradeKind) -> Int {
        switch kind {
        case .bellows: bellows
        case .counterweight: counterweight
        case .lavaSink: lavaSink
        case .assayLens: assayLens
        case .spiritLevel: spiritLevel
        }
    }

    mutating func setLevel(_ level: Int, for kind: UpgradeKind) {
        switch kind {
        case .bellows: bellows = level
        case .counterweight: counterweight = level
        case .lavaSink: lavaSink = level
        case .assayLens: assayLens = level
        case .spiritLevel: spiritLevel = level
        }
    }

    // MARK: - Weld heat

    /// Share of the cooling time (from the hot end) in which a dropped coin welds.
    var weldFraction: Double {
        min(0.6, Balance.baseWeldFraction + 0.06 * Double(bellows))
    }

    /// Multiplier on how long a coin takes to cool.
    var coolFactor: Double { keeper == .cinder ? 1.2 : 1 }

    // MARK: - Fulcrum

    /// How much stiffer the beam is than the starter beam.
    var restoringFactor: Double {
        (1 + 0.3 * Double(counterweight)) * (keeper == .basalt ? 1 / 0.75 : 1)
    }

    var steadyDegrees: Double { Balance.baseSteadyDegrees + 0.8 * Double(spiritLevel) }
    var multiplierCap: Double { Balance.baseMultiplierCap + 0.2 * Double(spiritLevel) }
    var startingMultiplier: Double { keeper == .pip ? 1.25 : 1 }

    // MARK: - Lava

    var lavaNotches: Int {
        Balance.baseLavaNotches + (lavaSink + 1) / 2 + (keeper == .ash ? 1 : 0)
    }

    /// Share of a spilled coin's gold that is lost.
    var spillPenalty: Double { keeper == .hermit ? 0.5 : 1 }

    // MARK: - Coins

    /// Combined chance that a new coin is gold or obsidian.
    var rareChance: Double { min(0.5, 0.22 + 0.04 * Double(assayLens)) }

    var mintBonus: Double { Balance.baseMintBonus * (keeper == .ember ? 1.5 : 1) }
}
