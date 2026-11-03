import Foundation
import Testing
import UIKit
@testable import CraterHoard

@MainActor
@Suite("Upgrades and keepers")
struct UpgradeAndKeeperTests {
    @Test func costsRiseWithEachLevel() {
        for kind in UpgradeKind.allCases {
            let costs = (1...kind.maxLevel).compactMap(kind.cost(forLevel:))
            #expect(costs.count == kind.maxLevel)
            #expect(costs == costs.sorted())
            #expect(costs.allSatisfy { $0 % 5 == 0 })
            #expect(kind.cost(forLevel: 0) == nil)
            #expect(kind.cost(forLevel: kind.maxLevel + 1) == nil)
        }
    }

    @Test func effectsDescribeTheLevel() {
        #expect(UpgradeKind.wheels.effectDescription(atLevel: 0) == "Speed x1")
        #expect(UpgradeKind.wheels.effectDescription(atLevel: 5) == "Speed x1.4")
        #expect(UpgradeKind.ironPlating.effectDescription(atLevel: 1) == "4 planks")
        #expect(UpgradeKind.waterTank.effectDescription(atLevel: 2) == "Heat tank 140")
        #expect(UpgradeKind.railSwitch.effectDescription(atLevel: 0) == "Switch 0.5 s")
    }

    @Test func everyUpgradeImprovesTheLoadout() {
        var loadout = Loadout.starter
        loadout.wheels = 3; loadout.waterTank = 3; loadout.ironPlating = 3; loadout.railSwitch = 3; loadout.sieve = 3
        let base = Loadout.starter
        #expect(loadout.cartSpeed > base.cartSpeed)
        #expect(loadout.heatCapacity > base.heatCapacity)
        #expect(loadout.planks > base.planks)
        #expect(loadout.switchTime < base.switchTime)
        #expect(loadout.valueFactor > base.valueFactor)
    }

    @Test func keepersHaveDistinctPerksAndRisingPrices() {
        let prices = Keeper.allCases.map(\.price)
        #expect(prices == prices.sorted())
        #expect(Keeper.starter.price == 0)
        #expect(Set(Keeper.allCases.map(\.perkTitle)).count == Keeper.allCases.count)
    }

    @Test func sieveRaisesCoinValue() {
        var loadout = Loadout.starter
        loadout.sieve = 5
        var session = RunSession(loadout: loadout, seed: 1, autoEvents: false)
        session.start()
        session.launch([(.coin(.gold), .lower, 0)], flightTime: 0.1)
        let events = session.run(for: 0.2)
        #expect(events.contains { if case .caught(_, 21) = $0 { true } else { false } }, "15 × 1.4")
    }

    @Test func payloadsHaveValueHeatAndArt() {
        #expect(Payload.core.value > Payload.coin(.gold).value)
        #expect(Payload.bomb.value == 0)
        #expect(Payload.coin(.copper).art == "coin_front_copper")
        #expect(Rail.lower.other == .upper)
    }
}

@MainActor
@Suite("Achievements")
struct AchievementTests {
    @Test func nothingIsUnlockedOnAFreshProfile() {
        let achievements = AchievementCatalog.evaluate(PlayerStats(hiredKeeperCount: 1))
        #expect(achievements.count == AchievementCatalog.count)
        #expect(achievements.allSatisfy { !$0.isUnlocked })
        #expect(Set(achievements.map(\.id)).count == achievements.count)
    }

    @Test func progressIsClampedAndUnlocksAtTheTarget() {
        let stats = PlayerStats(bestBank: 400, totalRuns: 3, totalBouldersBroken: 12, totalLightning: 10, hiredKeeperCount: 2)
        let byID = Dictionary(uniqueKeysWithValues: AchievementCatalog.evaluate(stats).map { ($0.id, $0) })
        #expect(byID["bank300"]?.isUnlocked == true)
        #expect(byID["bank300"]?.progress == 1)
        #expect(byID["lightning10"]?.isUnlocked == true)
        #expect(byID["boulders25"]?.isUnlocked == false)
        #expect(abs((byID["boulders25"]?.progress ?? 0) - 0.48) < 0.001)
        #expect(byID["keepers3"]?.art == "crystal_locked")
    }
}

@MainActor
@Suite("Settings and formatting")
struct SettingsAndFormattingTests {
    @Test func settingsPersistInDefaults() throws {
        let suite = "craterhoard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = SettingsStore(defaults: defaults)
        #expect(settings.hapticsEnabled && settings.soundEnabled)
        #expect(!settings.hasSeenGuide)
        settings.soundEnabled = false
        settings.hasSeenGuide = true

        let reloaded = SettingsStore(defaults: defaults)
        #expect(!reloaded.soundEnabled)
        #expect(reloaded.hasSeenGuide)
        #expect(reloaded.hapticsEnabled)
    }

    @Test func formattersReadWell() {
        #expect(Formatters.height(86) == "86 cm")
        #expect(Formatters.height(240) == "2.4 m")
        #expect(Formatters.height(300) == "3 m")
        #expect(Formatters.multiplier(1.25) == "x1.25")
        #expect(Formatters.multiplier(1.5) == "x1.5")
        #expect(Formatters.multiplier(2) == "x2")
        #expect(Formatters.duration(75) == "1:15")
        #expect(Formatters.percent(0.36) == "36%")
    }
}

@MainActor
@Suite("Generated assets")
struct AssetTests {
    /// actool can silently rename assets; every art name the code uses must resolve.
    @Test func everyArtworkResolves() {
        var names: [String] = [
            "bg_vault", "bg_sky", "volcano", "terrace", "rail_track", "mine_entrance", "cart", "cart_cargo",
            "volcanic_core", "lava_bomb", "boulder", "lightning_bolt", "ash_cloud", "plank", "plank_broken",
            "tex_paper", "tex_slate", "core_rock", "logo_wordmark", "hub_cart",
            "item_shelf", "item_lanterns", "item_core", "item_board", "item_valve", "item_lift", "valve_close",
            "fx_glow", "icon_gold", "plate", "medallion", "plaque", "shelf_plank", "lantern_frame", "tag_perk",
            "hud_thermo", "mine_cart", "jar_mask", "crystal_locked"
        ]
        names += CoinMetal.allCases.map(\.art)
        names += Keeper.allCases.map(\.portraitArt)
        names += UpgradeKind.allCases.map(\.jarArt)
        names += GuidePage.all.map(\.art)
        names += (0..<6).map { "crystal_\($0)" }
        let missing = names.filter { UIImage(named: $0) == nil }
        #expect(missing.isEmpty, "Missing art: \(missing)")
    }

    @Test func everySoundIsBundled() {
        let missing = SoundEffect.allCases.filter { Bundle.main.url(forResource: $0.rawValue, withExtension: "wav") == nil }
        #expect(missing.isEmpty, "Missing sounds: \(missing)")
        #expect(Bundle.main.url(forResource: "ambience_cave", withExtension: "wav") != nil)
    }
}
