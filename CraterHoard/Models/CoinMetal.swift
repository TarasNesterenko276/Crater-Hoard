import Foundation

/// The metals the crater spits out. Each metal has its own size, weight and value.
enum CoinMetal: String, CaseIterable, Codable, Sendable {
    case copper
    case silver
    case gold
    case obsidian

    var title: String {
        switch self {
        case .copper: "Copper"
        case .silver: "Silver"
        case .gold: "Gold"
        case .obsidian: "Obsidian"
        }
    }

    /// Side-view width of a coin in scene points. Rarer coins are smaller and harder to stack.
    var width: Double {
        switch self {
        case .copper: 86
        case .silver: 72
        case .gold: 58
        case .obsidian: 96
        }
    }

    var thickness: Double {
        switch self {
        case .copper: 17
        case .silver: 16
        case .gold: 15
        case .obsidian: 21
        }
    }

    /// Relative weight used for the balance beam and physics density.
    var weight: Double {
        switch self {
        case .copper: 1.0
        case .silver: 1.2
        case .gold: 1.5
        case .obsidian: 2.6
        }
    }

    /// Gold credited when a coin of this metal lands on the hoard.
    var value: Int {
        switch self {
        case .copper: 4
        case .silver: 8
        case .gold: 15
        case .obsidian: 30
        }
    }

    /// Obsidian is volcanic glass, so it never mints into an ingot.
    var canMint: Bool { self != .obsidian }

    var coinArt: String { "coin_\(rawValue)" }
    var ingotArt: String { "ingot_\(rawValue)" }
}

/// Anything that can sit on the balance beam: a loose coin or a minted ingot.
enum PieceKind: Equatable, Hashable, Sendable {
    case coin(CoinMetal)
    case ingot(CoinMetal)

    var metal: CoinMetal {
        switch self {
        case .coin(let metal), .ingot(let metal): metal
        }
    }

    var isIngot: Bool {
        if case .ingot = self { return true }
        return false
    }

    var width: Double {
        switch self {
        case .coin(let metal): metal.width
        case .ingot: Balance.ingotWidth
        }
    }

    var thickness: Double {
        switch self {
        case .coin(let metal): metal.thickness
        case .ingot: Balance.ingotThickness
        }
    }

    /// Ingots weigh as much as the three coins they were minted from.
    var weight: Double {
        switch self {
        case .coin(let metal): metal.weight
        case .ingot(let metal): metal.weight * 3
        }
    }

    var art: String {
        switch self {
        case .coin(let metal): metal.coinArt
        case .ingot(let metal): metal.ingotArt
        }
    }
}
