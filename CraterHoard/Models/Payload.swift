import Foundation

/// The two terraces cut into the volcano's slope.
enum Rail: Int, CaseIterable, Codable, Sendable {
    case lower = 0
    case upper = 1

    var other: Rail { self == .lower ? .upper : .lower }
    var title: String { self == .lower ? "Lower rail" : "Upper rail" }
}

/// Coin metals the crater throws.
enum CoinMetal: String, CaseIterable, Codable, Sendable {
    case copper
    case silver
    case gold

    var title: String { rawValue.capitalized }

    var value: Int {
        switch self {
        case .copper: 4
        case .silver: 8
        case .gold: 15
        }
    }

    /// Heat a coin of this metal adds to the cart.
    var heat: Double {
        switch self {
        case .copper: 6
        case .silver: 8
        case .gold: 11
        }
    }

    var art: String { "coin_front_\(rawValue)" }
}

/// Whatever a single eruption throws at the slope.
enum Payload: Equatable, Hashable, Sendable {
    case coin(CoinMetal)
    /// A rare glowing lump of the volcano's heart. Only reaches the upper rail.
    case core
    case bomb

    var isBomb: Bool { self == .bomb }

    var value: Int {
        switch self {
        case .coin(let metal): metal.value
        case .core: 60
        case .bomb: 0
        }
    }

    var heat: Double {
        switch self {
        case .coin(let metal): metal.heat
        case .core: 28
        case .bomb: 0
        }
    }

    var art: String {
        switch self {
        case .coin(let metal): metal.art
        case .core: "volcanic_core"
        case .bomb: "lava_bomb"
        }
    }
}

/// What the crater announces with its glow before a volley.
enum VolleyKind: String, Equatable, Sendable {
    /// Gold glow: only coins.
    case coins
    /// Red glow: only bombs.
    case bombs
    /// Two-tone glow: coins and bombs together.
    case mixed

    var title: String {
        switch self {
        case .coins: "Coin volley"
        case .bombs: "Bomb volley"
        case .mixed: "Mixed volley"
        }
    }
}

/// Something in the air on its way to a rail.
struct Projectile: Identifiable, Equatable, Sendable {
    let id: Int
    let payload: Payload
    let rail: Rail
    /// Landing position along the rail in `-1...1`.
    let x: Double
    let launchedAt: TimeInterval
    let landsAt: TimeInterval

    /// `0` at launch, `1` at landing.
    func progress(at time: TimeInterval) -> Double {
        let span = max(0.001, landsAt - launchedAt)
        return min(1, max(0, (time - launchedAt) / span))
    }
}

/// A hardened lava bomb blocking a rail.
struct Boulder: Identifiable, Equatable, Sendable {
    let id: Int
    let rail: Rail
    let x: Double
    let formedAt: TimeInterval
}

/// A lightning strike announced inside the ash cloud.
struct Lightning: Identifiable, Equatable, Sendable {
    let id: Int
    let rail: Rail
    let x: Double
    let strikesAt: TimeInterval
}
