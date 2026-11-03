import Foundation

/// Tuning constants for a shift on the slope. Positions along a rail are normalised to `-1...1`.
enum Balance {
    // Cart
    static let trackLimit: Double = 0.95
    static let cartHalfWidth: Double = 0.11
    static let catchRadius: Double = 0.15
    static let baseCartSpeed: Double = 1.5
    static let dashSpeedFactor: Double = 2.6
    static let dashDuration: Double = 0.32
    static let dashCooldown: Double = 1.1
    static let hitInvulnerability: Double = 1.0
    static let basePlanks = 3

    // Rails
    static let baseSwitchTime: Double = 0.5
    /// The lower rail banks at its left end, the upper rail at its right end.
    static let bankZone: Double = 0.86

    // Heat
    static let baseHeatCapacity: Double = 100
    static let carryHeatPerCoin: Double = 0.55
    static let upperRailHeatFactor: Double = 1.3
    static let coolingPerSecond: Double = 9
    static let heatAfterOverheat: Double = 0.4

    // Cargo
    static let cargoStep: Double = 0.08
    static let cargoMultiplierCap: Double = 2.0
    static let lightningCharge: Double = 0.5
    static let lightningChargeCap: Double = 1.5
    static let upperRailValueFactor: Double = 1.6

    // Volleys
    static let warningDuration: Double = 1.0
    static let firstVolleyDelay: Double = 1.2
    static let baseVolleyInterval: Double = 3.2
    static let minimumVolleyInterval: Double = 1.7
    static let baseFlightTime: Double = 1.6
    static let minimumFlightTime: Double = 1.05

    // Crust
    static let boulderHalfWidth: Double = 0.06
    static let boulderLifetime: Double = 30
    static let boulderShardGold = 12

    // Ash cloud
    static let ashPerProjectile: Double = 0.022
    static let ashPerBomb: Double = 0.035
    static let ashClearingPerSecond: Double = 0.022
    static let lightningThreshold: Double = 0.55
    static let lightningInterval: Double = 2.4
    static let lightningWarning: Double = 0.85
    static let lightningRadius: Double = 0.17
    static let lightningGold = 10
}
