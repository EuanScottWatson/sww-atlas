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

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 where !element.isHittable { app.swipeUp() }
    }

    func testCreateJourney() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Atlas Test Trip"].waitForExistence(timeout: 30))
        app.buttons["Add trip options"].tap()
        app.buttons["Add multi-stop journey"].tap()
        let name = app.textFields["Journey name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap(); name.typeText("Atlas Test Journey")
        let first = app.textFields.matching(identifier: "Destination").element(boundBy: 0)
        let second = app.textFields.matching(identifier: "Destination").element(boundBy: 1)
        reveal(first, in: app); XCTAssertTrue(first.isHittable)
        first.tap(); first.typeText("Atlas First Stop")
        reveal(second, in: app); XCTAssertTrue(second.isHittable)
        second.tap(); second.typeText("Atlas Second Stop")
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        let save = app.buttons["Save journey"]
        reveal(save, in: app); XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.staticTexts["Atlas First Stop"].waitForExistence(timeout: 15))
    }

    func testAddTripPlace() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Atlas Test Trip"].waitForExistence(timeout: 30))
        app.staticTexts["Atlas Test Trip"].firstMatch.tap()
        app.navigationBars.buttons["Edit"].tap()
        let choose = app.buttons["Choose a pin on the map"]
        reveal(choose, in: app); XCTAssertTrue(choose.isHittable)
        choose.tap()
        let place = app.textFields["Place name"]
        reveal(place, in: app); XCTAssertTrue(place.isHittable)
        place.tap(); place.typeText("Atlas Test Marker")
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        let add = app.buttons["Add selected place"]
        reveal(add, in: app); XCTAssertTrue(add.isHittable)
        add.tap()
        let save = app.buttons["Save"]
        reveal(save, in: app); XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.navigationBars["Atlas Test Trip"].waitForExistence(timeout: 15))
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
