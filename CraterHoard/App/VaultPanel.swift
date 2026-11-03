import Foundation

/// The rooms of the vault that open in the mine-hatch drawer.
enum VaultPanel: String, Identifiable, CaseIterable {
    case assay
    case lanterns
    case core
    case guide
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assay: "Assay Shelf"
        case .lanterns: "Lantern Row"
        case .core: "Core Sample"
        case .guide: "Notice Board"
        case .settings: "Valve Room"
        }
    }

    var subtitle: String {
        switch self {
        case .assay: "Upgrades"
        case .lanterns: "Keepers"
        case .core: "Records"
        case .guide: "How to play"
        case .settings: "Settings"
        }
    }
}
