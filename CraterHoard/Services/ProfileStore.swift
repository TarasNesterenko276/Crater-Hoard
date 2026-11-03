import Foundation
import Observation
import SwiftData

/// Errors surfaced to the interface when a purchase or selection is not possible.
enum ProfileError: LocalizedError, Equatable {
    case insufficientGold(needed: Int)
    case upgradeMaxed
    case keeperAlreadyHired
    case keeperNotHired

    var errorDescription: String? {
        switch self {
        case .insufficientGold(let needed):
            "You need \(Formatters.integer(needed)) more gold."
        case .upgradeMaxed:
            "This jar is already full."
        case .keeperAlreadyHired:
            "This keeper already works for you."
        case .keeperNotHired:
            "Hire this keeper before sending them to the claw."
        }
    }
}

/// Owns the player's profile and shift history on top of SwiftData.
/// All mutations go through here so views and view models never touch the model context.
@MainActor
@Observable
final class ProfileStore {
    private let context: ModelContext

    private(set) var profile: PlayerProfile
    private(set) var recentRuns: [RunRecord] = []
    /// Set when a save fails so the interface can tell the player.
    private(set) var persistenceErrorMessage: String?

    static let recentRunLimit = 24

    init(container: ModelContainer) throws {
        context = ModelContext(container)
        context.autosaveEnabled = false

        var descriptor = FetchDescriptor<PlayerProfile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            profile = existing
        } else {
            let created = PlayerProfile()
            context.insert(created)
            profile = created
            try context.save()
        }
        try reloadRuns()
    }

    // MARK: - Derived state

    var gold: Int { profile.gold }
    var loadout: Loadout { profile.loadout }

    var achievements: [Achievement] {
        AchievementCatalog.evaluate(profile.statsSnapshot)
    }

    func level(of kind: UpgradeKind) -> Int {
        profile.level(for: kind)
    }

    /// Cost of the next level, or `nil` when the upgrade is maxed.
    func nextCost(of kind: UpgradeKind) -> Int? {
        kind.cost(forLevel: profile.level(for: kind) + 1)
    }

    func canAfford(_ amount: Int) -> Bool {
        profile.gold >= amount
    }

    // MARK: - Mutations

    func purchaseUpgrade(_ kind: UpgradeKind) throws {
        guard let cost = nextCost(of: kind) else { throw ProfileError.upgradeMaxed }
        guard canAfford(cost) else { throw ProfileError.insufficientGold(needed: cost - profile.gold) }
        profile.gold -= cost
        profile.setLevel(profile.level(for: kind) + 1, for: kind)
        try save()
    }

    func hireKeeper(_ keeper: Keeper) throws {
        guard !profile.isHired(keeper) else { throw ProfileError.keeperAlreadyHired }
        guard canAfford(keeper.price) else { throw ProfileError.insufficientGold(needed: keeper.price - profile.gold) }
        profile.gold -= keeper.price
        profile.hiredKeeperIDs.append(keeper.rawValue)
        profile.selectedKeeperID = keeper.rawValue
        try save()
    }

    func selectKeeper(_ keeper: Keeper) throws {
        guard profile.isHired(keeper) else { throw ProfileError.keeperNotHired }
        profile.selectedKeeperID = keeper.rawValue
        try save()
    }

    /// Stores a finished shift, credits gold and updates lifetime statistics.
    @discardableResult
    func recordRun(_ summary: RunSummary) -> RunOutcome {
        let previousBestScore = profile.bestScore
        let previousBestHeight = profile.bestHeight
        let isNewBestScore = summary.score > previousBestScore
        let isNewBestHeight = summary.heightCentimetres > previousBestHeight

        profile.gold += summary.gold
        profile.totalRuns += 1
        profile.totalGoldEarned += summary.gold
        profile.totalCoinsLanded += summary.coinsLanded
        profile.totalMints += summary.mints
        profile.totalWelds += summary.welds
        profile.totalSpills += summary.spills
        profile.bestMultiplier = max(profile.bestMultiplier, summary.bestMultiplier)
        if isNewBestScore { profile.bestScore = summary.score }
        if isNewBestHeight { profile.bestHeight = summary.heightCentimetres }

        context.insert(RunRecord(summary: summary))
        persistQuietly()
        pruneOldRuns()

        return RunOutcome(
            summary: summary,
            previousBestScore: previousBestScore,
            previousBestHeight: previousBestHeight,
            isNewBestScore: isNewBestScore,
            isNewBestHeight: isNewBestHeight,
            totalGold: profile.gold
        )
    }

    /// Deletes every shift and restores the profile to its initial state.
    func resetProgress() throws {
        try context.delete(model: RunRecord.self)
        context.delete(profile)
        let fresh = PlayerProfile()
        context.insert(fresh)
        profile = fresh
        try save()
    }

    /// Grants gold without a shift. Used only to seed deterministic UI-test sessions.
    func grantGold(_ amount: Int) throws {
        profile.gold += amount
        try save()
    }

    // MARK: - Persistence helpers

    private func save() throws {
        try context.save()
        try reloadRuns()
        persistenceErrorMessage = nil
    }

    private func persistQuietly() {
        do {
            try save()
        } catch {
            persistenceErrorMessage = "Progress could not be saved: \(error.localizedDescription)"
        }
    }

    private func reloadRuns() throws {
        var descriptor = FetchDescriptor<RunRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = Self.recentRunLimit
        recentRuns = try context.fetch(descriptor)
    }

    /// Keeps the history bounded so the store never grows without limit.
    private func pruneOldRuns() {
        let descriptor = FetchDescriptor<RunRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let all = try? context.fetch(descriptor), all.count > Self.recentRunLimit else { return }
        for record in all.dropFirst(Self.recentRunLimit) {
            context.delete(record)
        }
        persistQuietly()
    }
}
