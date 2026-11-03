import Foundation

/// Tuning constants shared by the rules and the scene.
enum Balance {
    /// Width of the basalt beam that rests on the fulcrum, in scene points.
    static let beamWidth: Double = 280
    static let beamThickness: Double = 20

    static let ingotWidth: Double = 118
    static let ingotThickness: Double = 24

    /// Base seconds a fresh coin needs to cool completely in the claw.
    static let baseCoolDuration: Double = 3.4
    /// The claw cools coins faster as the hoard grows, down to this floor.
    static let minimumCoolDuration: Double = 2.0
    static let coolSpeedupPerCoin: Double = 0.025
    /// Delay between releasing a coin and the claw bringing the next one.
    static let reloadDelay: Double = 0.55

    /// Base fraction of the cooling time during which a coin is hot enough to weld.
    static let baseWeldFraction: Double = 0.30

    /// The beam can never tilt further than this (radians, about 18 degrees).
    static let maxTilt: Double = 0.32
    /// Load moment (weight × points) the beam absorbs per radian of tilt before upgrades.
    static let baseRestoringMoment: Double = 950

    static let baseLavaNotches = 4
    static let steadyStep: Double = 0.25
    static let baseMultiplierCap: Double = 2.0
    static let baseSteadyDegrees: Double = 4.0

    /// Share of the three coins' value paid on top when they mint into an ingot.
    static let baseMintBonus: Double = 0.5

    /// Scene points per centimetre of hoard height shown to the player (1 pt = 0.5 cm).
    static let centimetresPerPoint: Double = 0.5

    /// Chance that the next coin repeats the previous metal ("a vein").
    static let veinChance: Double = 0.38
}
