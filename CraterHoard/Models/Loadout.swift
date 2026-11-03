import Foundation

/// The gameplay numbers produced by the chosen keeper and the bought upgrades.
struct Loadout: Equatable, Sendable {
    var keeper: Keeper
    var wheels = 0
    var waterTank = 0
    var ironPlating = 0
    var railSwitch = 0
    var sieve = 0

    static let starter = Loadout(keeper: .starter)

    func level(for kind: UpgradeKind) -> Int {
        switch kind {
        case .wheels: wheels
        case .waterTank: waterTank
        case .ironPlating: ironPlating
        case .railSwitch: railSwitch
        case .sieve: sieve
        }
    }

    mutating func setLevel(_ level: Int, for kind: UpgradeKind) {
        switch kind {
        case .wheels: wheels = level
        case .waterTank: waterTank = level
        case .ironPlating: ironPlating = level
        case .railSwitch: railSwitch = level
        case .sieve: sieve = level
        }
    }

    /// Rail widths per second.
    var cartSpeed: Double { Balance.baseCartSpeed * (1 + 0.08 * Double(wheels)) }

    var heatCapacity: Double { Balance.baseHeatCapacity + 20 * Double(waterTank) }

    /// Multiplier on heat gained while carrying.
    var heatFactor: Double { keeper == .cinder ? 0.75 : 1 }

    var planks: Int { Balance.basePlanks + (ironPlating + 1) / 2 }

    var switchTime: Double { max(0.2, Balance.baseSwitchTime - 0.06 * Double(railSwitch)) }

    var valueFactor: Double { 1 + 0.08 * Double(sieve) }

    /// How far from the rail end the mine entrance accepts cargo.
    var bankZone: Double { keeper == .pip ? Balance.bankZone - 0.14 : Balance.bankZone }

    var breaksBouldersOnContact: Bool { keeper == .basalt }
    var seesThroughAsh: Bool { keeper == .ash }
    var lightningFactor: Int { keeper == .ember ? 2 : 1 }
    /// Share of the cargo kept after a bomb hit.
    var cargoKeptOnHit: Double { keeper == .hermit ? 0.5 : 0 }
}
