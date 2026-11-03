import Foundation
import SwiftData

/// A persisted record of one finished shift, drawn as a layer of the core sample.
@Model
final class RunRecord {
    var date: Date = Date.now
    var score: Int = 0
    var gold: Int = 0
    var duration: TimeInterval = 0
    var coinsCaught: Int = 0
    var bestBank: Int = 0
    var bouldersBroken: Int = 0
    var lightningCaught: Int = 0
    var keeperID: String = Keeper.starter.rawValue

    init(summary: RunSummary, date: Date = .now) {
        self.date = date
        score = summary.score
        gold = summary.gold
        duration = summary.duration
        coinsCaught = summary.coinsCaught
        bestBank = summary.bestBank
        bouldersBroken = summary.bouldersBroken
        lightningCaught = summary.lightningCaught
        keeperID = summary.keeperID
    }

    var keeper: Keeper {
        Keeper(rawValue: keeperID) ?? .starter
    }
}
