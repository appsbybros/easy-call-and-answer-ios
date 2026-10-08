import XCTest

final class EasyCallUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ locale:String = "en",large:Bool=false,demo:Bool=true) -> XCUIApplication {
        let app=XCUIApplication()
        app.launchArguments=["-AppleLanguages","(\(locale))","-AppleLocale",locale == "he" ? "he_IL" : "en_US"]
        if demo { app.launchArguments.append("--screenshots") }
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch(); return app
    }
    private func capture(_ name:String) {
        // UI actions can return while a sheet is animating. Capture the settled real screen.
        Thread.sleep(forTimeInterval:1)
        let item=XCTAttachment(screenshot:XCUIScreen.main.screenshot());item.name=name;item.lifetime = .keepAlways;add(item)
    }
    private func selectTab(_ title:String,in app:XCUIApplication) {
        // iPad exposes its floating tabs as ordinary buttons, without a TabBar ancestor.
        let tab=app.buttons.matching(identifier:title).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout:5));tab.tap()
    }
    func testEnglishScreensAndSafeCalling() throws {
        let app=launch()
        XCTAssertTrue(app.buttons["Call Maya"].waitForExistence(timeout:10)); capture("en-01-people")
        app.buttons["Call Maya"].tap()
        XCTAssertTrue(app.alerts.staticTexts["This is a practice contact. No call was placed."].waitForExistence(timeout:3))
        app.alerts.buttons["OK"].tap()
        app.buttons["Maya, Details and reminders"].tap()
        XCTAssertTrue(app.buttons["FaceTime Audio"].waitForExistence(timeout:5));capture("en-02-person")
        app.buttons["Done"].tap()
        selectTab("Keypad",in:app)
        for digit in ["0","2","5","5","5","0","1","2","3"] {app.buttons[digit].tap()}
        XCTAssertEqual(app.textFields["dial-number"].value as? String,"025550123")
        XCTAssertTrue(app.buttons["Call"].isHittable,"Digits and Call must fit a portrait phone at the standard text size")
        capture("en-03-keypad")
        selectTab("Help",in:app);capture("en-04-help")
        selectTab("People",in:app);app.buttons["Settings"].tap();capture("en-05-settings")
    }
    func testHebrewScreens() throws {
        let app=launch("he")
        XCTAssertTrue(app.buttons["התקשרות Maya"].waitForExistence(timeout:10));capture("he-01-people")
        selectTab("מקשים",in:app);capture("he-02-keypad")
        selectTab("עזרה",in:app);capture("he-03-help")
    }
    func testAccessibilitySizeAndLandscape() throws {
        let app=launch(large:true)
        XCTAssertTrue(app.buttons["Call Maya"].waitForExistence(timeout:10))
        for _ in 0..<3 where !app.buttons["Call Maya"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["Call Maya"].isHittable)
        capture("accessibility-people")
        selectTab("Keypad",in:app)
        XCUIDevice.shared.orientation = .landscapeLeft
        capture("landscape-keypad-accessibility")
        app.buttons["1"].tap();app.buttons["2"].tap()
        let call=app.buttons["Call"]
        for _ in 0..<8 where !call.isHittable {app.swipeUp()}
        XCTAssertTrue(call.isHittable,"The Call control must remain reachable at maximum text size in landscape")
        XCTAssertTrue(call.isEnabled)
        capture("landscape-call-accessibility")
        XCUIDevice.shared.orientation = .portrait
    }
    func testManualContactPersistsAndCanBeRemoved() throws {
        let app=launch(demo:false)
        app.buttons["Add a person"].tap()
        let name=app.textFields["Name"];XCTAssertTrue(name.waitForExistence(timeout:5));name.tap();name.typeText("QA Contact")
        // On a compact phone the next field sits behind the keyboard. Use the
        // visible dismissal control, exactly as a person would, before tapping it.
        app.buttons["Done"].tap()
        let phone=app.textFields["Phone number"];phone.tap();phone.typeText("+12025550199")
        XCTAssertEqual(phone.value as? String,"+12025550199")
        app.buttons["Done"].tap()
        app.swipeUp();app.buttons["Save person"].tap()
        XCTAssertTrue(app.buttons["Call QA Contact"].waitForExistence(timeout:5))
        app.terminate();app.launch()
        XCTAssertTrue(app.buttons["Call QA Contact"].waitForExistence(timeout:5))
        app.buttons["QA Contact, Details and reminders"].tap()
        app.swipeUp();app.buttons["Remove"].tap()
        let removeButtons=app.buttons.matching(identifier:"Remove").allElementsBoundByIndex
        try XCTUnwrap(removeButtons.first(where: { $0.isHittable })).tap()
        XCTAssertTrue(app.buttons["Start with someone you love"].exists || app.staticTexts["Start with someone you love"].waitForExistence(timeout:5))
    }
}
