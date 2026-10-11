import XCTest

/// Launches with `-uiTesting -fixedDay 2026-10-12 -resetState` (in-memory stores, fixed seeds);
/// `-onboarded` skips the questionnaire except in `testCompleteOnboarding`.
@MainActor
final class SmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-fixedDay", "2026-10-12", "-resetState"]
        if !name.contains("testCompleteOnboarding") { app.launchArguments.append("-onboarded") }
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func waitFor(_ id: String, timeout: TimeInterval = 10) -> XCUIElement {
        let e = element(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "missing \(id)")
        return e
    }

    /// Scrolls the hub until a tile is hittable, then taps it.
    private func openMode(_ raw: String) {
        let tile = waitFor("mode.\(raw)")
        var tries = 0
        while !tile.isHittable && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        tile.tap()
    }

    private func tapNext() {
        let next = waitFor("session.next")
        let deadline = Date().addingTimeInterval(5)
        while !next.isHittable && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
        next.tap()
    }

    func testHomeRenders() {
        XCTAssertTrue(waitFor("home.title").exists)
        XCTAssertTrue(element("home.date").exists)
        XCTAssertTrue(element("home.daily").exists)
        XCTAssertTrue(element("mode.pick_price").exists)
        XCTAssertTrue(element("mode.higher_lower").exists)
    }

    func testPickThePriceOneRound() {
        openMode("pick_price")
        waitFor("pick.option.0").tap()
        XCTAssertTrue(waitFor("reveal.result").exists)
        tapNext()
        let label = waitFor("session.progressLabel")
        XCTAssertEqual(label.label.lowercased(), "lot 2 of 10")
        XCTAssertTrue(waitFor("pick.option.0").exists)
    }

    func testBidOneRound() {
        openMode("bid")
        XCTAssertTrue(waitFor("bid.live").exists)
        waitFor("bid.place").tap()
        XCTAssertTrue(waitFor("bid.tier").exists)
        tapNext()
        XCTAssertEqual(waitFor("session.progressLabel").label.lowercased(), "lot 2 of 10")
        XCTAssertTrue(waitFor("bid.place").exists)
    }

    func testQuitPricierRun() {
        openMode("higher_lower")
        XCTAssertTrue(waitFor("pricier.top").exists)
        waitFor("session.close").tap()
        let leave = app.buttons["Leave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5))
        leave.tap()
        XCTAssertTrue(waitFor("home.title").exists)
        XCTAssertFalse(element("pricier.top").exists)
    }

    /// Waits until an element exists and is hittable (crossfades and cover presentation), then taps.
    private func tapWhenReady(_ id: String, timeout: TimeInterval = 10) {
        let e = waitFor(id, timeout: timeout)
        let deadline = Date().addingTimeInterval(timeout)
        while !e.isHittable && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
        e.tap()
    }

    func testCompleteOnboarding() {
        tapWhenReady("onboarding.choice.classic")
        tapWhenReady("onboarding.choice.old_masters")
        tapWhenReady("onboarding.continue")
        tapWhenReady("onboarding.choice.subject:landscape")
        tapWhenReady("onboarding.choice.mood:serene")
        tapWhenReady("onboarding.intent.play")
        XCTAssertTrue(waitFor("home.title").exists)
        XCTAssertFalse(element("onboarding.title").exists)
    }

    func testCategoryRound() {
        openMode("category")
        waitFor("category.option.0").tap()
        XCTAssertTrue(waitFor("category.teach").exists)
        tapNext()
        XCTAssertEqual(waitFor("session.progressLabel").label.lowercased(), "lot 2 of 10")
    }

    func testFinishDaily() {
        tapWhenReady("home.daily.play")
        for round in 0..<5 {
            tapWhenReady("daily.start")
            // Whichever kind this round is: the first answer control that appears.
            let candidates = ["pick.option.0", "pricier.top", "category.option.0", "bid.place"]
            let deadline = Date().addingTimeInterval(10)
            var answered = false
            while !answered && Date() < deadline {
                if let id = candidates.first(where: { element($0).exists && element($0).isHittable }) {
                    element(id).tap()
                    answered = true
                } else {
                    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
                }
            }
            XCTAssertTrue(answered, "no answer control in round \(round + 1)")
            tapNext()
        }
        XCTAssertTrue(waitFor("daily.total").exists)
        XCTAssertTrue(element("daily.countdown").exists)
        waitFor("summary.home").tap()
        XCTAssertTrue(waitFor("home.daily.practice").exists)
    }
}
