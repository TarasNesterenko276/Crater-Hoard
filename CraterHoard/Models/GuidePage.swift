import Foundation

/// One notice pinned on the board: explains a rule of the slope.
struct GuidePage: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let body: String
    let art: String

    static let all: [GuidePage] = [
        GuidePage(
            id: 0,
            title: "Read the crater's glow",
            body: "Before every volley the crater glows: gold means coins, red means lava bombs, both colours mean a mix. Shadows grow on the rails where things will land. Drag to roll the cart under the coins and away from the bombs.",
            art: "guide_volley"
        ),
        GuidePage(
            id: 1,
            title: "Hot cargo, cool water",
            body: "Caught coins are hot and the cart's heat gauge rises while you carry them. Roll into the mine entrance at the end of the rail to bank them and cool down. The more you carry, the bigger the multiplier, but a bomb knocks the cargo out and overheating costs a plank.",
            art: "guide_cargo"
        ),
        GuidePage(
            id: 2,
            title: "Break the obsidian",
            body: "Bombs you avoid harden into obsidian boulders that block the rail. Tap to dash and smash through them for shards of gold. Boulders crumble on their own after a while.",
            art: "guide_crust"
        ),
        GuidePage(
            id: 3,
            title: "Two rails",
            body: "Swipe up or down to jump between rails. The upper rail near the crater has richer coins and rare volcanic cores, but more bombs and more heat. While jumping you can't catch anything and bombs on either rail can hit you.",
            art: "guide_rails"
        ),
        GuidePage(
            id: 4,
            title: "Ride the ash cloud",
            body: "Big volleys fill the sky with ash. The thicker the cloud, the fainter the landing shadows. But a thick cloud sparks lightning: stand under a flickering mark to catch it for gold and a bigger bank multiplier.",
            art: "guide_ash"
        )
    ]
}
