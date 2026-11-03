import Foundation
import Observation

/// Paging through the notices on the board. When opened before the first shift,
/// finishing the guide starts the game.
@MainActor
@Observable
final class GuideViewModel {
    let pages = GuidePage.all
    let startsShiftWhenDone: Bool
    var pageIndex = 0

    private let settings: SettingsStore
    private let onFinish: (_ startShift: Bool) -> Void

    init(settings: SettingsStore, startsShiftWhenDone: Bool, onFinish: @escaping (_ startShift: Bool) -> Void) {
        self.settings = settings
        self.startsShiftWhenDone = startsShiftWhenDone
        self.onFinish = onFinish
    }

    var isLastPage: Bool { pageIndex >= pages.count - 1 }

    var primaryTitle: String {
        guard isLastPage else { return "Next notice" }
        return startsShiftWhenDone ? "Start my first shift" : "Got it"
    }

    func advance() {
        if isLastPage {
            settings.hasSeenGuide = true
            onFinish(startsShiftWhenDone)
        } else {
            pageIndex += 1
        }
    }
}
