import Foundation

/// The values the SwiftUI HUD displays, mirrored from the running scene a few times per second.
struct GameHUDState: Equatable, Sendable {
    var gold = 0
    var planks: Int
    var maxPlanks: Int
    var heatFraction: Double = 0
    var cargoCount = 0
    var cargoMultiplier: Double = 1
    var rail: Rail = .lower
    var isSwitching = false
    var canDash = true
    var ash: Double = 0
    var isAshStorm = false
    var elapsed: TimeInterval = 0
    var warning: VolleyKind?

    /// Direction of the mine entrance on the current rail: -1 left, +1 right.
    var bankSide: Double { RunSession.bankSide(of: rail) }

    init(loadout: Loadout) {
        planks = loadout.planks
        maxPlanks = loadout.planks
    }

    init(session: RunSession) {
        self.init(loadout: session.loadout)
        gold = session.gold
        planks = session.planks
        heatFraction = session.heatFraction
        cargoCount = session.cargoCount
        cargoMultiplier = session.cargoMultiplier
        rail = session.cart.switchingTo ?? session.cart.rail
        isSwitching = session.cart.isSwitching
        canDash = session.cart.dashCooldown <= 0
        ash = session.ash
        isAshStorm = session.isAshStorm
        elapsed = session.elapsed
        warning = session.warning?.kind
    }
}
