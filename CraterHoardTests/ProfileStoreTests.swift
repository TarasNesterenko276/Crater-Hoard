import Foundation
import SwiftData
import Testing
@testable import CraterHoard

@MainActor
@Suite("Profile store")
struct ProfileStoreTests {
    private func makeStore() throws -> (ProfileStore, ModelContainer) {
        let container = try PersistenceController.makeContainer(inMemory: true)
        return (try ProfileStore(container: container), container)
    }

    private func summary(gold: Int = 120, bestBank: Int = 60, seconds: Double = 80) -> RunSummary {
        RunSummary(score: gold + Int(seconds) * 2, gold: gold, duration: seconds, coinsCaught: 12, coresCaught: 1, banks: 3,
                   bestBank: bestBank, bouldersBroken: 2, lightningCaught: 1, volleys: 20, keeperID: Keeper.pip.rawValue)
    }

    @Test func freshProfileStartsEmptyWithTheStarterKeeper() throws {
        let (store, _) = try makeStore()
        #expect(store.gold == 0)
        #expect(store.loadout.keeper == .pip)
        #expect(store.recentRuns.isEmpty)
        #expect(UpgradeKind.allCases.allSatisfy { store.level(of: $0) == 0 })
    }

    @Test func purchasingAnUpgradeSpendsGoldAndRaisesTheLevel() throws {
        let (store, _) = try makeStore()
        try store.grantGold(500)
        let cost = try #require(store.nextCost(of: .wheels))
        try store.purchaseUpgrade(.wheels)
        #expect(store.level(of: .wheels) == 1)
        #expect(store.gold == 500 - cost)
        #expect(store.loadout.wheels == 1)
    }

    @Test func purchaseIsRefusedWithoutEnoughGold() throws {
        let (store, _) = try makeStore()
        try store.grantGold(10)
        #expect(throws: ProfileError.insufficientGold(needed: 50)) {
            try store.purchaseUpgrade(.wheels)
        }
        #expect(store.gold == 10)
        #expect(store.level(of: .wheels) == 0)
    }

    @Test func maxedUpgradesCannotBeBought() throws {
        let (store, _) = try makeStore()
        try store.grantGold(100_000)
        for _ in 0..<UpgradeKind.railSwitch.maxLevel { try store.purchaseUpgrade(.railSwitch) }
        #expect(store.nextCost(of: .railSwitch) == nil)
        #expect(throws: ProfileError.upgradeMaxed) { try store.purchaseUpgrade(.railSwitch) }
    }

    @Test func hiringAKeeperPutsThemInTheCart() throws {
        let (store, _) = try makeStore()
        try store.grantGold(Keeper.cinder.price)
        try store.hireKeeper(.cinder)
        #expect(store.gold == 0)
        #expect(store.loadout.keeper == .cinder)
        #expect(throws: ProfileError.keeperAlreadyHired) { try store.hireKeeper(.cinder) }
        try store.selectKeeper(.pip)
        #expect(store.loadout.keeper == .pip)
    }

    @Test func lockedKeepersCannotBeHiredOrSelected() throws {
        let (store, _) = try makeStore()
        #expect(throws: ProfileError.insufficientGold(needed: Keeper.hermit.price)) { try store.hireKeeper(.hermit) }
        #expect(throws: ProfileError.keeperNotHired) { try store.selectKeeper(.hermit) }
        #expect(store.loadout.keeper == .pip)
    }

    @Test func recordingAShiftBanksGoldAndUpdatesRecords() throws {
        let (store, _) = try makeStore()
        let first = store.recordRun(summary(gold: 100, bestBank: 80))
        #expect(first.isNewBestScore && first.isNewBestBank)
        #expect(first.totalGold == 100)
        let second = store.recordRun(summary(gold: 20, bestBank: 40, seconds: 30))
        #expect(!second.isNewBestScore && !second.isNewBestBank)
        #expect(second.previousBestBank == 80)
        #expect(store.profile.totalRuns == 2)
        #expect(store.profile.totalCores == 2)
        #expect(store.profile.bestBank == 80)
        #expect(store.profile.longestShift == 80)
        #expect(store.recentRuns.count == 2)
        #expect(store.recentRuns.first?.gold == 20, "Newest shift first")
    }

    @Test func progressSurvivesANewStoreOnTheSameContainer() throws {
        let (store, container) = try makeStore()
        try store.grantGold(Keeper.cinder.price + 200)
        try store.hireKeeper(.cinder)
        try store.purchaseUpgrade(.wheels)
        store.recordRun(summary())

        let reopened = try ProfileStore(container: container)
        #expect(reopened.loadout.keeper == .cinder)
        #expect(reopened.level(of: .wheels) == 1)
        #expect(reopened.recentRuns.count == 1)
        #expect(reopened.gold == store.gold)
    }

    @Test func historyIsTrimmedToTheLimit() throws {
        let (store, _) = try makeStore()
        for index in 0..<(ProfileStore.recentRunLimit + 5) {
            store.recordRun(summary(gold: index))
        }
        #expect(store.recentRuns.count == ProfileStore.recentRunLimit)
        #expect(store.profile.totalRuns == ProfileStore.recentRunLimit + 5)
    }

    @Test func resetEmptiesTheVault() throws {
        let (store, _) = try makeStore()
        try store.grantGold(5_000)
        try store.purchaseUpgrade(.ironPlating)
        try store.hireKeeper(.basalt)
        store.recordRun(summary())
        try store.resetProgress()
        #expect(store.gold == 0)
        #expect(store.level(of: .ironPlating) == 0)
        #expect(store.loadout.keeper == .pip)
        #expect(store.recentRuns.isEmpty)
        #expect(store.profile.totalRuns == 0)
    }

    @Test func achievementsGrowFromRecordedShifts() throws {
        let (store, _) = try makeStore()
        #expect(store.achievements.allSatisfy { !$0.isUnlocked })
        store.recordRun(summary(gold: 150, bestBank: 120, seconds: 130))
        let unlocked = Set(store.achievements.filter(\.isUnlocked).map(\.id))
        #expect(unlocked.isSuperset(of: ["firstShift", "bank100", "shift120"]))
        #expect(!unlocked.contains("bank300"))
    }
}
