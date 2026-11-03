import XCTest

/// Walks every screen and keeps full-resolution screenshots as attachments
/// (exported for the website and the store listing with `xcresulttool export attachments`).
final class ScreenshotTourTests: CraterHoardUITestCase {
    @MainActor
    func testTourEveryScreen() {
        launch(["--history", "--autopilot"])
        shoot("01-vault")

        openPanel("vault.assay", expecting: "assay.screen")
        element("assay.buy.wheels").tap()
        waitForToast(prefix: "Greased Wheels brewed")
        XCTAssertTrue(element("toast").waitForNonExistence(timeout: 5))
        shoot("02-assay-shelf")
        closeDrawer()

        openPanel("vault.lanterns", expecting: "lanterns.screen")
        element("lanterns.keeper.ember").tap()
        shoot("03-lantern-row")
        closeDrawer()

        openPanel("vault.core", expecting: "core.screen")
        shoot("04-core-sample")
        closeDrawer()

        openPanel("vault.board", expecting: "guide.screen")
        element("guide.next").tap()
        shoot("05-notice-cargo")
        element("guide.next").tap()
        shoot("06-notice-crust")
        closeDrawer()

        element("vault.play").tap()
        XCTAssertTrue(element("game.start").waitForExistence(timeout: 6))
        shoot("07-briefing")
        element("game.start").tap()
        XCTAssertTrue(element("game.countdown").waitForNonExistence(timeout: 8))
        sleep(9)
        shoot("08-shift-volley")
        sleep(7)
        shoot("09-shift-ash")
        XCTAssertTrue(element("game.slate").waitForExistence(timeout: 90))
        sleep(2)
        shoot("10-chalk-slate")
    }

    private func shoot(_ name: String) {
        // Let springs and fades settle.
        usleep(600_000)
        attach(name)
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
