import XCTest

final class AtlasNativeUITests: XCTestCase {
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ATLAS_TEST_BASE"] = "http://127.0.0.1:18780"
        app.launch()
        return app
    }

    func testTripCalendarAndEventSave() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Atlas Test Trip"].waitForExistence(timeout: 30))
        capture(app, name: "Trips")
        app.staticTexts["Atlas Test Trip"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Atlas Test Event"].waitForExistence(timeout: 10))
        capture(app, name: "Trip detail")
        app.staticTexts["Atlas Test Event"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Atlas Test Event"].waitForExistence(timeout: 10))
        app.navigationBars.buttons["Edit"].tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10))
        capture(app, name: "Event editor")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Atlas Test Event"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Statistics"].tap()
        XCTAssertTrue(app.staticTexts["Your travel"].waitForExistence(timeout: 10))
        capture(app, name: "Statistics")
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 10))
        capture(app, name: "Calendar")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Atlas Test Event")
        XCTAssertTrue(app.staticTexts["Atlas Test Event"].waitForExistence(timeout: 10))
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        app.tabBars.buttons["Map"].tap()
        XCTAssertTrue(app.navigationBars["Map"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 10))
        capture(app, name: "Map")
    }

    func testCreateTrip() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Atlas Test Trip"].waitForExistence(timeout: 30))
        app.buttons["Add trip options"].tap()
        app.buttons["Add trip"].tap()
        let destination = app.textFields["Destination"]
        XCTAssertTrue(destination.waitForExistence(timeout: 10))
        destination.tap()
        destination.typeText("Atlas New Trip")
        let year = app.textFields["Allocation year"]
        year.tap()
        year.typeText("2027")
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        app.swipeUp()
        let save = app.buttons["Save"]
        for _ in 0..<5 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.staticTexts["Atlas New Trip"].waitForExistence(timeout: 15))
    }
}
