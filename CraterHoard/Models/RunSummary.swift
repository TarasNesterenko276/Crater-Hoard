import Foundation

/// The result of one finished shift, produced by `RunSession`.
struct RunSummary: Equatable, Sendable {
    var score: Int
    var gold: Int
    var duration: TimeInterval
    var coinsCaught: Int
    var coresCaught: Int
    var banks: Int
    var bestBank: Int
    var bouldersBroken: Int
    var lightningCaught: Int
    var volleys: Int
    var keeperID: String
}

/// A summary plus how it compares to the player's previous records.
struct RunOutcome: Equatable, Sendable {
    let summary: RunSummary
    let previousBestScore: Int
    let previousBestBank: Int
    let isNewBestScore: Bool
    let isNewBestBank: Bool
    let totalGold: Int
}
