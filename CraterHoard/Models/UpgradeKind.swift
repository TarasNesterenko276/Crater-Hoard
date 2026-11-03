import Foundation

/// Permanent upgrades brewed on the assay shelf and paid for with gold.
enum UpgradeKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case bellows
    case counterweight
    case lavaSink
    case assayLens
    case spiritLevel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bellows: "Bellows"
        case .counterweight: "Counterweight"
        case .lavaSink: "Lava Sink"
        case .assayLens: "Assay Lens"
        case .spiritLevel: "Spirit Level"
        }
    }

    var summary: String {
        switch self {
        case .bellows: "Keeps coins glowing longer, widening the weld window."
        case .counterweight: "Heavier beam ends: the fulcrum tilts less under load."
        case .lavaSink: "Drains the pit so it takes more spills to reach the beam."
        case .assayLens: "The crater spits more gold and obsidian coins."
        case .spiritLevel: "A wider steady zone and a higher steady multiplier cap."
        }
    }

    var jarArt: String { "jar_\(rawValue)" }

    var maxLevel: Int { 5 }

    var baseCost: Int {
        switch self {
        case .bellows: 60
        case .counterweight: 90
        case .lavaSink: 120
        case .assayLens: 100
        case .spiritLevel: 80
        }
    }

    /// Gold cost to reach `level` (1-based). Returns `nil` when `level` is out of range.
    func cost(forLevel level: Int) -> Int? {
        guard level >= 1, level <= maxLevel else { return nil }
        let raw = Double(baseCost) * pow(1.7, Double(level - 1))
        // Round to a friendly multiple of five.
        return Int((raw / 5).rounded()) * 5
    }

    /// Human readable effect at a given level, e.g. "Weld window 36%".
    func effectDescription(atLevel level: Int) -> String {
        var loadout = Loadout.starter
        loadout.setLevel(level, for: self)
        switch self {
        case .bellows:
            return "Weld window \(Formatters.percent(loadout.weldFraction))"
        case .counterweight:
            return "Tilt \(Formatters.percent(1 / loadout.restoringFactor))"
        case .lavaSink:
            return "\(loadout.lavaNotches) lava notches"
        case .assayLens:
            return "Rare coins \(Formatters.percent(loadout.rareChance))"
        case .spiritLevel:
            return "±\(Formatters.oneDecimal(loadout.steadyDegrees))° · cap \(Formatters.multiplier(loadout.multiplierCap))"
        }
    }
}
