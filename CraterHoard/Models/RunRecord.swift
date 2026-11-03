import Foundation
import SwiftData

/// A persisted record of one finished shift, drawn as a layer of the core sample.
@Model
final class RunRecord {
    var date: Date
    var score: Int
    var gold: Int
    var heightCentimetres: Int
    var mints: Int
    var welds: Int
    var spills: Int
    var duration: TimeInterval
    var keeperID: String

    init(summary: RunSummary, date: Date = .now) {
        self.date = date
        score = summary.score
        gold = summary.gold
        heightCentimetres = summary.heightCentimetres
        mints = summary.mints
        welds = summary.welds
        spills = summary.spills
        duration = summary.duration
        keeperID = summary.keeperID
    }

    var keeper: Keeper {
        Keeper(rawValue: keeperID) ?? .starter
    }
}
