import Foundation

/// Accessibility identifiers shared with the UI tests (duplicated there as plain strings).
enum AccessibilityID {
    enum Vault {
        static let screen = "vault.screen"
        static let play = "vault.play"
        static let gold = "vault.gold"
        static let assay = "vault.assay"
        static let lanterns = "vault.lanterns"
        static let core = "vault.core"
        static let board = "vault.board"
        static let settings = "vault.settings"
        static let keeper = "vault.keeper"
    }

    enum Drawer {
        static let close = "drawer.close"
        static let backdrop = "drawer.backdrop"
    }

    enum Assay {
        static let screen = "assay.screen"
        static func buy(_ kind: UpgradeKind) -> String { "assay.buy.\(kind.rawValue)" }
        static func level(_ kind: UpgradeKind) -> String { "assay.level.\(kind.rawValue)" }
    }

    enum Lanterns {
        static let screen = "lanterns.screen"
        static let action = "lanterns.action"
        static let selectedName = "lanterns.selectedName"
        static func lantern(_ keeper: Keeper) -> String { "lanterns.keeper.\(keeper.rawValue)" }
    }

    enum Core {
        static let screen = "core.screen"
        static let empty = "core.empty"
        static let stats = "core.stats"
        static let geode = "core.geode"
        static let bestScore = "core.bestScore"
    }

    enum Guide {
        static let screen = "guide.screen"
        static let next = "guide.next"
        static let done = "guide.done"
    }

    enum Settings {
        static let screen = "settings.screen"
        static let haptics = "settings.haptics"
        static let sound = "settings.sound"
        static let guide = "settings.guide"
        static let reset = "settings.reset"
        static let resetConfirm = "settings.resetConfirm"
    }

    enum Game {
        static let screen = "game.screen"
        static let start = "game.start"
        static let leave = "game.leave"
        static let countdown = "game.countdown"
        static let pause = "game.pause"
        static let resume = "game.resume"
        static let restart = "game.restart"
        static let quit = "game.quit"
        static let slate = "game.slate"
        static let again = "game.again"
        static let toVault = "game.toVault"
        static let toAssay = "game.toAssay"
        static let gold = "hud.gold"
        static let planks = "hud.planks"
        static let ash = "hud.ash"
        static let heat = "hud.heat"
        static let cargo = "hud.cargo"
        static let callout = "hud.callout"
        static let dash = "game.dash"
        static let switchRail = "game.switchRail"
    }

    static let toast = "toast"
}
