import XCTest

/// Shared launch and lookup helpers. The app runs with `--uitesting`: in-memory save,
/// silent audio, guide marked as read and 1,000 gold seeded.
class CraterHoardUITestCase: XCTestCase {
    var app: XCUIApplication!

    func launch(_ extra: [String] = []) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"] + extra
        app.launch()
        XCTAssertTrue(element("vault.screen").waitForExistence(timeout: 10), "Vault did not appear")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func waitFor(_ identifier: String, timeout: TimeInterval = 6, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(identifier).waitForExistence(timeout: timeout), "Expected \(identifier)", file: file, line: line)
    }

    func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Digits of an element's value or label, so "1.000" and "1,000" compare the same.
    func digits(_ element: XCUIElement) -> Int? {
        let text = (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
        return Int(text.filter(\.isNumber))
    }

    func openPanel(_ object: String, expecting screen: String) {
        element(object).tap()
        waitFor(screen)
    }

    func closeDrawer() {
        let close = element("drawer.close")
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 4), "Drawer did not close")
    }

    func waitForToast(prefix: String, file: StaticString = #filePath, line: UInt = #line) {
        // One query for identifier and text avoids racing the toast's own dismissal.
        let toast = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", "toast", prefix))
            .firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast starting with '\(prefix)'", file: file, line: line)
    }

    /// Starts a shift from the vault and waits until the countdown is over.
    func startShift() {
        element("vault.play").tap()
        waitFor("game.screen")
        let start = element("game.start")
        XCTAssertTrue(start.waitForExistence(timeout: 6))
        start.tap()
        let countdown = element("game.countdown")
        XCTAssertTrue(countdown.waitForExistence(timeout: 4), "Countdown never started")
        XCTAssertTrue(countdown.waitForNonExistence(timeout: 8), "Countdown never finished")
    }
}

final class CraterHoardUITests: CraterHoardUITestCase {
    // MARK: - Vault

    @MainActor
    func testVaultShowsEveryObject() {
        launch()
        for id in ["vault.play", "vault.gold", "vault.assay", "vault.lanterns", "vault.core", "vault.board", "vault.settings", "vault.keeper"] {
            XCTAssertTrue(element(id).exists, "\(id) missing")
        }
        XCTAssertEqual(digits(element("vault.gold")), 1_000)
    }

    @MainActor
    func testOpensEveryRoomAndClosesIt() {
        launch()
        openPanel("vault.assay", expecting: "assay.screen")
        closeDrawer()
        openPanel("vault.lanterns", expecting: "lanterns.screen")
        closeDrawer()
        openPanel("vault.core", expecting: "core.screen")
        closeDrawer()
        openPanel("vault.board", expecting: "guide.screen")
        closeDrawer()
        openPanel("vault.settings", expecting: "settings.screen")
        closeDrawer()
        openPanel("vault.keeper", expecting: "lanterns.screen")
        // Tapping the dimmed vault behind the hatch also closes it.
        // Top-left corner is outside the hatch on both iPhone (bottom sheet) and iPad (side drawer).
        element("drawer.backdrop").coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.08)).tap()
        XCTAssertTrue(element("lanterns.screen").waitForNonExistence(timeout: 4))
    }

    // MARK: - Assay shelf

    @MainActor
    func testBrewingAnUpgradeSpendsGold() {
        launch()
        openPanel("vault.assay", expecting: "assay.screen")
        let level = element("assay.level.bellows")
        XCTAssertTrue(level.label.hasPrefix("Lv 0"))
        element("assay.buy.bellows").tap()
        waitForToast(prefix: "Bellows brewed")
        XCTAssertTrue(level.label.hasPrefix("Lv 1"))
        closeDrawer()
        XCTAssertEqual(digits(element("vault.gold")), 1_000 - 60)
    }

    @MainActor
    func testBrewingIsRefusedWithoutGold() {
        launch(["--broke"])
        openPanel("vault.assay", expecting: "assay.screen")
        element("assay.buy.lavaSink").tap()
        waitForToast(prefix: "You need")
        XCTAssertTrue(element("assay.level.lavaSink").label.hasPrefix("Lv 0"))
    }

    // MARK: - Lantern row

    @MainActor
    func testHiringAKeeperSendsThemToTheClaw() {
        launch()
        openPanel("vault.lanterns", expecting: "lanterns.screen")
        element("lanterns.keeper.cinder").tap()
        XCTAssertTrue(element("lanterns.selectedName").label == "Cinder")
        element("lanterns.action").tap()
        waitForToast(prefix: "Cinder joined")
        closeDrawer()
        XCTAssertTrue(element("vault.keeper").label.contains("Cinder"))
        XCTAssertEqual(digits(element("vault.gold")), 1_000 - 450)
    }

    @MainActor
    func testExpensiveKeeperIsRefused() {
        launch()
        openPanel("vault.lanterns", expecting: "lanterns.screen")
        element("lanterns.keeper.hermit").tap()
        element("lanterns.action").tap()
        waitForToast(prefix: "You need")
        closeDrawer()
        XCTAssertTrue(element("vault.keeper").label.contains("Pip"))
    }

    // MARK: - Core sample

    @MainActor
    func testCoreSampleIsEmptyBeforeTheFirstShift() {
        launch()
        openPanel("vault.core", expecting: "core.screen")
        XCTAssertTrue(element("core.empty").exists)
        XCTAssertTrue(element("core.geode").exists)
    }

    @MainActor
    func testCoreSampleShowsHistory() {
        launch(["--history"])
        openPanel("vault.core", expecting: "core.screen")
        XCTAssertFalse(element("core.empty").exists)
        XCTAssertTrue(element("core.bestHeight").label.contains("1.7 m"))
    }

    // MARK: - Settings

    @MainActor
    func testResetEmptiesTheVault() {
        launch()
        openPanel("vault.assay", expecting: "assay.screen")
        element("assay.buy.bellows").tap()
        waitForToast(prefix: "Bellows brewed")
        closeDrawer()
        openPanel("vault.settings", expecting: "settings.screen")
        element("settings.reset").tap()
        let confirm = app.buttons["Empty the vault"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 4))
        confirm.tap()
        waitForToast(prefix: "The vault is empty")
        closeDrawer()
        XCTAssertEqual(digits(element("vault.gold")), 0)
    }

    @MainActor
    func testTogglesPersistWhileTheAppRuns() {
        launch()
        openPanel("vault.settings", expecting: "settings.screen")
        let sound = element("settings.sound")
        let before = sound.value as? String
        sound.switches.firstMatch.tap()
        XCTAssertNotEqual(sound.value as? String, before)
        closeDrawer()
        openPanel("vault.settings", expecting: "settings.screen")
        XCTAssertNotEqual(element("settings.sound").value as? String, before)
    }

    // MARK: - Guide

    @MainActor
    func testFirstShiftReadsTheNoticeBoardFirst() {
        launch(["--show-guide"])
        element("vault.play").tap()
        waitFor("guide.screen")
        for _ in 0..<4 {
            let next = element("guide.next")
            XCTAssertTrue(next.waitForExistence(timeout: 3))
            next.tap()
        }
        let done = element("guide.done")
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        done.tap()
        waitFor("game.screen")
        XCTAssertTrue(element("game.start").waitForExistence(timeout: 5))
    }

    // MARK: - Shift

    @MainActor
    func testShiftStartPauseResumeAndLeave() {
        launch()
        startShift()
        let pause = element("game.pause")
        XCTAssertTrue(waitForHittable(pause), "Pause never became tappable")
        XCTAssertTrue(element("hud.lava").exists)
        XCTAssertTrue(element("hud.dial").exists)
        pause.tap()
        waitFor("game.resume")
        element("game.resume").tap()
        XCTAssertTrue(element("game.resume").waitForNonExistence(timeout: 3))
        XCTAssertTrue(waitForHittable(pause))
        pause.tap()
        waitFor("game.quit")
        element("game.quit").tap()
        waitFor("vault.screen")
        XCTAssertTrue(element("game.screen").waitForNonExistence(timeout: 4))
    }

    @MainActor
    func testLeavingFromTheBriefingReturnsToTheVault() {
        launch()
        element("vault.play").tap()
        waitFor("game.start")
        element("game.leave").tap()
        XCTAssertTrue(element("game.screen").waitForNonExistence(timeout: 4))
    }

    @MainActor
    func testAutopilotShiftEndsOnTheChalkSlateAndBanksGold() {
        launch(["--autopilot"])
        startShift()
        let slate = element("game.slate")
        XCTAssertTrue(slate.waitForExistence(timeout: 90), "Shift never ended")
        element("game.toVault").tap()
        waitFor("vault.screen")
        XCTAssertGreaterThan(digits(element("vault.gold")) ?? 0, 1_000, "Gold from the shift was not banked")
        openPanel("vault.core", expecting: "core.screen")
        XCTAssertFalse(element("core.empty").exists)
    }

    // MARK: - iPad

    @MainActor
    func testLandscapeLayoutOnPad() throws {
        launch()
        // The test runner's own idiom is unreliable; judge by the app window instead.
        let screen = XCUIScreen.main.screenshot().image.size
        try XCTSkipUnless(min(screen.width, screen.height) >= 700, "iPad only (screen \(screen))")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(element("vault.play").waitForExistence(timeout: 4))
        XCTAssertTrue(element("vault.play").isHittable)
        XCTAssertTrue(element("vault.assay").isHittable)
        XCTAssertTrue(element("vault.board").isHittable)
        attach("pad-landscape-vault")
        openPanel("vault.assay", expecting: "assay.screen")
        XCTAssertTrue(element("assay.buy.bellows").isHittable)
        attach("pad-landscape-assay")
        closeDrawer()
        element("vault.play").tap()
        let start = element("game.start")
        XCTAssertTrue(start.waitForExistence(timeout: 6))
        XCTAssertTrue(waitForHittable(start))
        attach("pad-landscape-briefing")
        start.tap()
        XCTAssertTrue(element("game.countdown").waitForNonExistence(timeout: 10), "Countdown never finished")
        let pause = element("game.pause")
        XCTAssertTrue(pause.waitForExistence(timeout: 4), "Shift did not start in landscape")
        sleep(2)
        attach("pad-landscape-shift")
        // Hittability snapshots are unreliable over a live, rotated SpriteKit view; tap by coordinate.
        pause.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(element("game.resume").waitForExistence(timeout: 4), "Pause menu did not open")
    }

    func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
