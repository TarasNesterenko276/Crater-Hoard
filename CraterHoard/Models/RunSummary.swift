import Foundation

/// The result of one finished shift, produced by `RunSession`.
struct RunSummary: Equatable, Sendable {
    var score: Int
    var gold: Int
    var heightCentimetres: Int
    var coinsLanded: Int
    var mints: Int
    var welds: Int
    var spills: Int
    var bestMultiplier: Double
    var duration: TimeInterval
    var keeperID: String
}

/// A summary plus how it compares to the player's previous records.
struct RunOutcome: Equatable, Sendable {
    let summary: RunSummary
    let previousBestScore: Int
    let previousBestHeight: Int
    let isNewBestScore: Bool
    let isNewBestHeight: Bool
    let totalGold: Int
}
