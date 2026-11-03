import Foundation

/// Permanent upgrades for the cart and the mine, brewed on the assay shelf with gold.
enum UpgradeKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case wheels
    case waterTank
    case ironPlating
    case railSwitch
    case sieve

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wheels: "Greased Wheels"
        case .waterTank: "Water Tank"
        case .ironPlating: "Iron Plating"
        case .railSwitch: "Rail Switch"
        case .sieve: "Gold Sieve"
        }
    }

    var summary: String {
        switch self {
        case .wheels: "The cart rolls faster along the rails."
        case .waterTank: "A bigger tank: the cart holds more heat before it overheats."
        case .ironPlating: "Extra planks of armour against lava bombs."
        case .railSwitch: "Jump between the rails faster and spend less time exposed."
        case .sieve: "Every coin you catch is worth more gold."
        }
    }

    var jarArt: String { "jar_\(rawValue)" }

    var maxLevel: Int { 5 }

    var baseCost: Int {
        switch self {
        case .wheels: 60
        case .waterTank: 80
        case .ironPlating: 140
        case .railSwitch: 70
        case .sieve: 100
        }
    }

    /// Gold cost to reach `level` (1-based). Returns `nil` when `level` is out of range.
    func cost(forLevel level: Int) -> Int? {
        guard level >= 1, level <= maxLevel else { return nil }
        let raw = Double(baseCost) * pow(1.7, Double(level - 1))
        // Round to a friendly multiple of five.
        return Int((raw / 5).rounded()) * 5
    }

    /// Human readable effect at a given level, e.g. "Speed x1.2".
    func effectDescription(atLevel level: Int) -> String {
        var loadout = Loadout.starter
        loadout.setLevel(level, for: self)
        switch self {
        case .wheels:
            return "Speed \(Formatters.multiplier(loadout.cartSpeed / Balance.baseCartSpeed))"
        case .waterTank:
            return "Heat tank \(Int(loadout.heatCapacity))"
        case .ironPlating:
            return "\(loadout.planks) planks"
        case .railSwitch:
            return "Switch \(Formatters.oneDecimal(loadout.switchTime)) s"
        case .sieve:
            return "Coins \(Formatters.multiplier(loadout.valueFactor))"
        }
    }
}
