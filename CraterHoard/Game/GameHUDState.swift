import Foundation

/// The values the SwiftUI HUD displays, mirrored from the running scene a few times per second.
struct GameHUDState: Equatable, Sendable {
    var gold = 0
    var heightCentimetres = 0
    var peakHeightCentimetres = 0
    var lavaLevel = 0
    var lavaCapacity: Int
    /// Beam tilt in radians, positive when the right end dips.
    var tilt: Double = 0
    var steadyLimit: Double
    var multiplier: Double
    var multiplierCap: Double
    var heat: Double = 0
    var weldThreshold: Double
    var isHolding = false
    var upcoming: CoinMetal = .copper
    var mints = 0
    var coinsLanded = 0

    var isSteady: Bool { abs(tilt) <= steadyLimit }
    var isWeldHot: Bool { isHolding && heat >= weldThreshold }
    var lavaFraction: Double { lavaCapacity == 0 ? 0 : Double(lavaLevel) / Double(lavaCapacity) }

    init(loadout: Loadout) {
        lavaCapacity = loadout.lavaNotches
        steadyLimit = loadout.steadyDegrees * .pi / 180
        multiplier = loadout.startingMultiplier
        multiplierCap = loadout.multiplierCap
        weldThreshold = 1 - loadout.weldFraction
    }

    init(session: RunSession) {
        self.init(loadout: session.loadout)
        gold = session.gold
        heightCentimetres = session.heightCentimetres
        peakHeightCentimetres = session.peakHeightCentimetres
        lavaLevel = session.lavaLevel
        tilt = session.tilt
        multiplier = session.multiplier
        heat = session.held?.heat ?? 0
        isHolding = session.held != nil
        upcoming = session.upcoming
        mints = session.mints
        coinsLanded = session.coinsLanded
    }
}
