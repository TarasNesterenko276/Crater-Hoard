import Foundation

/// One notice pinned on the board: explains a rule of the crater.
struct GuidePage: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let body: String
    let art: String

    static let all: [GuidePage] = [
        GuidePage(
            id: 0,
            title: "Catch the crater's coins",
            body: "Drag anywhere to slide the claw. Lift your finger to drop the coin onto the balance beam. Every coin that lands adds gold to the hoard.",
            art: "guide_drop"
        ),
        GuidePage(
            id: 1,
            title: "Weld while it glows",
            body: "Fresh coins are molten and cool in the claw. Drop one while the heat bar is in the bright band and it welds to the coin below. Wait too long and the claw lets go on its own.",
            art: "guide_weld"
        ),
        GuidePage(
            id: 2,
            title: "Mint three of a kind",
            body: "Stack three coins of the same metal right on top of each other and they fuse into a wide, flat ingot. Minting pays bonus gold and cools the lava one notch. Obsidian never mints.",
            art: "guide_mint"
        ),
        GuidePage(
            id: 3,
            title: "Keep the fulcrum level",
            body: "The beam balances on a single rock. Weight off-centre tips it. Every coin landed while the dial needle is in the green raises the steady multiplier; tipping out of it resets it.",
            art: "guide_fulcrum"
        ),
        GuidePage(
            id: 4,
            title: "Mind the lava",
            body: "Each coin that falls off the beam sinks into the lava, takes its gold with it and raises the lava a notch. When the lava reaches the beam, the shift is over.",
            art: "guide_lava"
        )
    ]
}
