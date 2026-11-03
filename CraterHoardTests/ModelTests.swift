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
        #expect(UpgradeKind.bellows.effectDescription(atLevel: 0) == "Weld window 30%")
        #expect(UpgradeKind.bellows.effectDescription(atLevel: 5) == "Weld window 60%")
        #expect(UpgradeKind.lavaSink.effectDescription(atLevel: 1) == "5 lava notches")
        #expect(UpgradeKind.assayLens.effectDescription(atLevel: 0) == "Rare coins 22%")
    }

    @Test func everyUpgradeImprovesTheLoadout() {
        var loadout = Loadout.starter
        loadout.bellows = 3; loadout.counterweight = 3; loadout.lavaSink = 3; loadout.assayLens = 3; loadout.spiritLevel = 3
        let base = Loadout.starter
        #expect(loadout.weldFraction > base.weldFraction)
        #expect(loadout.restoringFactor > base.restoringFactor)
        #expect(loadout.lavaNotches > base.lavaNotches)
        #expect(loadout.rareChance > base.rareChance)
        #expect(loadout.steadyDegrees > base.steadyDegrees)
        #expect(loadout.multiplierCap > base.multiplierCap)
    }

    @Test func keepersHaveDistinctPerksAndRisingPrices() {
        let prices = Keeper.allCases.map(\.price)
        #expect(prices == prices.sorted())
        #expect(Keeper.starter.price == 0)
        #expect(Set(Keeper.allCases.map(\.perkTitle)).count == Keeper.allCases.count)
    }

    @Test func assayLensBringsMoreRareCoins() {
        func rareShare(_ lens: Int) -> Double {
            var loadout = Loadout.starter
            loadout.assayLens = lens
            var session = RunSession(loadout: loadout, seed: 77)
            _ = session.start()
            var rare = 0
            for _ in 0..<400 {
                if session.held == nil { _ = session.advance(by: 1) }
                if let metal = session.held?.metal, metal == .gold || metal == .obsidian { rare += 1 }
                session.dropAndLand(on: .beam)
            }
            return Double(rare) / 400
        }
        #expect(rareShare(5) > rareShare(0))
    }

    @Test func pieceKindsUseTheirMetal() {
        #expect(PieceKind.coin(.gold).width == CoinMetal.gold.width)
        #expect(PieceKind.ingot(.gold).width == Balance.ingotWidth)
        #expect(PieceKind.ingot(.silver).weight == CoinMetal.silver.weight * 3)
        #expect(PieceKind.ingot(.copper).art == "ingot_copper")
        #expect(CoinMetal.allCases.filter(\.canMint).count == 3)
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
        let stats = PlayerStats(bestHeight: 400, totalRuns: 3, totalMints: 12, bestMultiplier: 2.2, hiredKeeperCount: 2)
        let byID = Dictionary(uniqueKeysWithValues: AchievementCatalog.evaluate(stats).map { ($0.id, $0) })
        #expect(byID["height250"]?.isUnlocked == true)
        #expect(byID["height250"]?.progress == 1)
        #expect(byID["steady"]?.isUnlocked == true)
        #expect(byID["mints25"]?.isUnlocked == false)
        #expect(abs((byID["mints25"]?.progress ?? 0) - 0.48) < 0.001)
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
            "bg_vault", "bg_shaft", "tex_paper", "tex_slate", "core_rock", "logo_wordmark", "hub_balance",
            "item_shelf", "item_lanterns", "item_core", "item_board", "item_valve", "item_lift", "valve_close",
            "beam", "fulcrum", "claw", "chain", "lava_crust", "fx_glow", "icon_gold", "plate", "medallion", "plaque",
            "shelf_plank", "lantern_frame", "tag_perk", "hud_dial", "hud_needle", "hud_thermo", "hud_ruler",
            "mine_cart", "jar_mask", "crystal_locked"
        ]
        names += CoinMetal.allCases.map(\.coinArt)
        names += CoinMetal.allCases.filter(\.canMint).map(\.ingotArt)
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
