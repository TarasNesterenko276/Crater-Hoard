import Foundation

/// The cave creatures who operate the claw. Each one brings a passive perk.
enum Keeper: String, CaseIterable, Identifiable, Codable, Sendable {
    case pip
    case cinder
    case basalt
    case ash
    case ember
    case hermit

    static let starter: Keeper = .pip

    var id: String { rawValue }

    var name: String {
        switch self {
        case .pip: "Pip"
        case .cinder: "Cinder"
        case .basalt: "Basalt"
        case .ash: "Ash"
        case .ember: "Ember"
        case .hermit: "Hermit"
        }
    }

    var species: String {
        switch self {
        case .pip: "Tunnel mole"
        case .cinder: "Fire salamander"
        case .basalt: "Stone golem"
        case .ash: "Cave owl"
        case .ember: "Lava fox"
        case .hermit: "Hermit crab"
        }
    }

    var perkTitle: String {
        switch self {
        case .pip: "Old Hand"
        case .cinder: "Warm Grip"
        case .basalt: "Heavy Feet"
        case .ash: "Night Watch"
        case .ember: "Mint Master"
        case .hermit: "Shell Pocket"
        }
    }

    var perkDetail: String {
        switch self {
        case .pip: "Knows every tunnel. Starts each shift with a x1.25 steady bonus."
        case .cinder: "Coins stay hot 20% longer in the claw, so welds are easier."
        case .basalt: "Stands on the beam's short end: the beam tilts 25% less."
        case .ash: "Spots the lava early: one extra lava notch before the shift ends."
        case .ember: "Minting an ingot pays 50% more bonus gold."
        case .hermit: "Spilled coins only cost half their gold."
        }
    }

    /// Gold needed to hire this keeper. The starter is free.
    var price: Int {
        switch self {
        case .pip: 0
        case .cinder: 450
        case .basalt: 900
        case .ash: 1_500
        case .ember: 2_400
        case .hermit: 3_600
        }
    }

    var portraitArt: String { "keeper_\(rawValue)" }
}
