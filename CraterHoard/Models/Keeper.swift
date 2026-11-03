import Foundation

/// The cave creatures who ride the cart. Each one brings a passive perk.
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
        case .cinder: "Cool Blood"
        case .basalt: "Battering Ram"
        case .ash: "Night Eyes"
        case .ember: "Storm Chaser"
        case .hermit: "Shell Pocket"
        }
    }

    var perkDetail: String {
        switch self {
        case .pip: "Knows every tunnel: the mine entrances bank from twice as far."
        case .cinder: "The cart heats up 25% slower while carrying coins."
        case .basalt: "Breaks obsidian boulders just by rolling into them, no dash needed."
        case .ash: "Sees through the ash cloud: landing shadows never fade."
        case .ember: "Lightning caught in the ash cloud pays double."
        case .hermit: "A lava bomb only knocks half of the cargo out of the cart."
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
