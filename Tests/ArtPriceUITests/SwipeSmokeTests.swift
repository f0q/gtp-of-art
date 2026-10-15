import XCTest

/// Swipe → taste reveal, and the Collection, with `-uiTesting -fixedDay 2026-10-12 -resetState -onboarded`.
@MainActor
final class SwipeSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-fixedDay", "2026-10-12", "-resetState", "-onboarded"]
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @discardableResult
    private func waitFor(_ id: String, timeout: TimeInterval = 10) -> XCUIElement {
        let e = element(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "missing \(id)")
        return e
    }

    private func waitHittable(_ e: XCUIElement, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while !(e.exists && e.isHittable && e.isEnabled) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }

    private func openMode(_ raw: String) {
        let tile = waitFor("mode.\(raw)")
        var tries = 0
        while !tile.isHittable && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        tile.tap()
    }

    func testTwentySwipesRevealTaste() {
        openMode("swipe")
        waitFor("swipe.stack")
        let like = app.buttons["Keep"]
        let pass = app.buttons["Pass"]
        XCTAssertTrue(like.waitForExistence(timeout: 10))
        for n in 0..<20 {
            let button = n % 3 == 2 ? pass : like
            waitHittable(button)
            button.tap()
            if n == 7 {
                XCTAssertEqual(waitFor("swipe.copy").label, "11 more to reveal your taste")
            }
            if n == 0 {
                // One-level undo restores the card; swipe it again.
                let undo = app.buttons["Undo"]
                waitHittable(undo)
                undo.tap()
                waitHittable(like)
                like.tap()
            }
        }
        XCTAssertTrue(waitFor("taste.wall", timeout: 15).exists)
        if element("taste.skip").exists { element("taste.skip").tap() }
        XCTAssertTrue(waitFor("taste.archetype").exists)
        XCTAssertTrue(waitFor("taste.share", timeout: 15).exists)
        XCTAssertTrue(waitFor("taste.again").exists)
    }

    /// Every swipe gesture has a labelled button: Pass, Undo, Details (swipe up), Keep.
    func testSwipeButtonAlternatives() {
        openMode("swipe")
        waitFor("swipe.stack")
        let expected = ["swipe.pass": "Pass", "swipe.undo": "Undo", "swipe.details": "Details", "swipe.keep": "Keep"]
        for (id, label) in expected {
            let button = waitFor(id)
            XCTAssertEqual(button.label, label, id)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, id)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, id)
        }
        let details = waitFor("swipe.details")
        waitHittable(details)
        details.tap()
        XCTAssertTrue(app.navigationBars["About this work"].waitForExistence(timeout: 5))
        app.navigationBars["About this work"].buttons["Done"].tap()
        XCTAssertTrue(waitFor("swipe.keep").exists)
    }

    func testCollectionOpens() {
        waitFor("home.profile").tap()
        waitFor("profile.collection").tap()
        XCTAssertTrue(waitFor("collection.count").exists)
        XCTAssertTrue(element("collection.count").label.contains("0 /"))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        waitFor("profile.taste").tap()
        XCTAssertTrue(waitFor("taste.swipeMore").exists)
    }
}
