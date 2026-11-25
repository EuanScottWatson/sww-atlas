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
        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents([.year,.month],from:Date())
        components.day = 1
        let firstDay = calendar.date(from:components)!
        let formatter = DateFormatter(); formatter.locale = Locale(identifier:"en_GB"); formatter.dateStyle = .medium
        let firstLabel = formatter.string(from:firstDay) + ","
        let firstDate = app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@",firstLabel)).firstMatch
        XCTAssertTrue(firstDate.waitForExistence(timeout: 10), "The first day of the month must be visible")
        capture(app, name: "Calendar")
        let target = calendar.date(from:DateComponents(year:2026,month:5,day:1))!
        let current = calendar.date(from:components)!
        let delta = calendar.dateComponents([.month],from:current,to:target).month ?? 0
        if delta != 0 {
            let button = app.buttons[delta < 0 ? "Previous month" : "Next month"]
            for _ in 0..<abs(delta) { button.tap() }
        }
        let eventDay = app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","2 May 2026,")).firstMatch
        XCTAssertTrue(eventDay.waitForExistence(timeout:10)); eventDay.tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Atlas Test Trip"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["Atlas Test Event"].waitForExistence(timeout:10))
        app.swipeDown()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Atlas Test Event")
        XCTAssertTrue(app.staticTexts["Atlas Test Event"].waitForExistence(timeout: 10))
        search.typeText("\n")
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
        let first = app.textFields["journey-destination-1"]
        let second = app.textFields["journey-destination-2"]
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

    func testEditAnnualFigures() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Atlas Test Trip"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Statistics"].tap()
        let year = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "All years")).firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: 10)); year.tap()
        let chosen = app.buttons["2026"]
        XCTAssertTrue(chosen.waitForExistence(timeout: 10)); chosen.tap()
        let edit = app.buttons["Edit annual figures"]
        reveal(edit, in: app); XCTAssertTrue(edit.isHittable); edit.tap()
        let remaining = app.textFields["Leave remaining"]
        reveal(remaining, in: app); XCTAssertTrue(remaining.isHittable)
        remaining.tap()
        remaining.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + "7")
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        let save = app.buttons["Save figures"]
        reveal(save, in: app); XCTAssertTrue(save.isHittable); save.tap()
        XCTAssertTrue(app.navigationBars["Statistics"].waitForExistence(timeout: 15))
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
