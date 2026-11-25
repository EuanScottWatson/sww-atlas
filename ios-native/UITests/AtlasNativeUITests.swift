import XCTest

final class AtlasNativeUITests: XCTestCase {
    func testTripCalendarAndEventSave() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ATLAS_TEST_BASE"] = "http://127.0.0.1:18780"
        app.launch()
        XCTAssertTrue(app.staticTexts["Atlas Test Trip"].waitForExistence(timeout: 30))
        app.staticTexts["Atlas Test Trip"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Atlas Test Event"].waitForExistence(timeout: 10))
        app.staticTexts["Atlas Test Event"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Atlas Test Event"].waitForExistence(timeout: 10))
        app.navigationBars.buttons["Edit"].tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Atlas Test Event"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Statistics"].tap()
        XCTAssertTrue(app.staticTexts["Your travel"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Map"].tap()
        XCTAssertTrue(app.navigationBars["Map"].waitForExistence(timeout: 10))
        let attachment=XCTAttachment(screenshot:app.screenshot())
        attachment.name="Atlas map"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
