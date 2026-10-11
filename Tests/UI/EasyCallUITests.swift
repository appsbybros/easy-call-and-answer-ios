import XCTest

final class EasyCallUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }
    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        XCUIApplication().terminate()
    }
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
    private func reveal(_ element:XCUIElement,in app:XCUIApplication) {
        // Drag within the target's scroll view, including a centered iPad sheet.
        // Whole-screen gestures can land outside that sheet; generic swipeUp()
        // also recorded a horizontal path after rotation on the newer runtime.
        let scroll=app.scrollViews.containing(.button,identifier:element.label).firstMatch
        let surface=scroll.exists ? scroll : app
        for _ in 0..<20 where !element.isHittable {
            let top=surface.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.25))
            let bottom=surface.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.75))
            if element.exists && element.frame.midY < surface.frame.minY+surface.frame.height*0.2 {
                top.press(forDuration:0.05,thenDragTo:bottom)
            } else {
                bottom.press(forDuration:0.05,thenDragTo:top)
            }
        }
        XCTAssertTrue(element.isHittable)
    }
    private func dismissKeyboard(_ title:String = "Done",in app:XCUIApplication) {
        // Every text field offers a Done control above its keyboard; tap the one on screen.
        let controls=app.buttons.matching(identifier:title)
        XCTAssertTrue(controls.firstMatch.waitForExistence(timeout:5),"A \(title) control closes the keyboard")
        let visible=controls.allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(visible,"The \(title) control must be on screen")
        visible?.tap()
    }
    private func shows(_ text:String,in app:XCUIApplication) -> Bool {
        app.descendants(matching:.any).matching(identifier:text).firstMatch.waitForExistence(timeout:5)
    }
    private func removeOpenPerson(_ remove:String = "Remove",in app:XCUIApplication) throws {
        let button=app.buttons[remove];reveal(button,in:app);button.tap()
        try XCTUnwrap(app.buttons.matching(identifier:remove).allElementsBoundByIndex.first(where: { $0.isHittable })).tap()
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
        defer { XCUIDevice.shared.orientation = .portrait }
        capture("landscape-keypad-accessibility")
        app.buttons["1"].tap();app.buttons["2"].tap()
        let call=app.buttons["Call"]
        reveal(call,in:app)
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
        dismissKeyboard(in:app)
        let phone=app.textFields["Phone number"];phone.tap();phone.typeText("+12025550199")
        XCTAssertEqual(phone.value as? String,"+12025550199")
        dismissKeyboard(in:app)
        let save=app.buttons["Save person"];reveal(save,in:app);save.tap()
        XCTAssertTrue(app.buttons["Call QA Contact"].waitForExistence(timeout:5))
        app.terminate();app.launch()
        XCTAssertTrue(app.buttons["Call QA Contact"].waitForExistence(timeout:5))
        app.buttons["QA Contact, Details and reminders"].tap()
        let remove=app.buttons["Remove"];reveal(remove,in:app);remove.tap()
        let removeButtons=app.buttons.matching(identifier:"Remove").allElementsBoundByIndex
        try XCTUnwrap(removeButtons.first(where: { $0.isHittable })).tap()
        XCTAssertTrue(app.buttons["Start with someone you love"].exists || app.staticTexts["Start with someone you love"].waitForExistence(timeout:5))
    }
    // QA ISSUE-002: digits typed in the contact form's phone field did not show on an iPad.
    func testPhoneNumberIsTypedCorrectedEditedAndSaved() throws {
        let app=launch(demo:false)
        app.buttons["Add a person"].tap()
        let name=app.textFields["Name"];XCTAssertTrue(name.waitForExistence(timeout:5));name.tap();name.typeText("Phone Check")
        dismissKeyboard(in:app)
        let phone=app.textFields["Phone number"];XCTAssertTrue(phone.waitForExistence(timeout:5));phone.tap()
        phone.typeText("+97254305063")
        XCTAssertEqual(phone.value as? String,"+97254305063","Every digit appears where it is typed")
        // Correct a mistyped ending in place: delete two digits, then type the right ones.
        phone.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:2)+"636")
        XCTAssertEqual(phone.value as? String,"+972543050636")
        capture("qa-en-phone-entry")
        dismissKeyboard(in:app)
        let save=app.buttons["Save person"];reveal(save,in:app);save.tap()
        XCTAssertTrue(app.buttons["Call Phone Check"].waitForExistence(timeout:5))
        app.buttons["Phone Check, Details and reminders"].tap()
        XCTAssertTrue(shows("+972543050636",in:app))
        // Edit the saved number: the form shows it, it can be deleted and replaced.
        let edit=app.buttons["Edit"];reveal(edit,in:app);edit.tap()
        let saved=app.textFields["Phone number"];XCTAssertTrue(saved.waitForExistence(timeout:5))
        XCTAssertEqual(saved.value as? String,"+972543050636")
        // Tap after the digits so the caret starts at the end of the number.
        saved.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5)).tap()
        saved.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:20)+"0501234567")
        XCTAssertEqual(saved.value as? String,"0501234567")
        dismissKeyboard(in:app)
        let update=app.buttons["Save person"];reveal(update,in:app);update.tap()
        XCTAssertTrue(shows("0501234567",in:app))
        // Leave no saved people behind for the next test.
        try removeOpenPerson(in:app)
        XCTAssertTrue(app.buttons["Start with someone you love"].exists || app.staticTexts["Start with someone you love"].waitForExistence(timeout:5))
    }
    func testHebrewPhoneNumberIsTypedAndSaved() throws {
        let app=launch("he",demo:false)
        let add=app.buttons["הוספת איש קשר"];XCTAssertTrue(add.waitForExistence(timeout:10));add.tap()
        let name=app.textFields["שם"];XCTAssertTrue(name.waitForExistence(timeout:5));name.tap();name.typeText("QA")
        dismissKeyboard("סיום",in:app)
        let phone=app.textFields["מספר טלפון"];XCTAssertTrue(phone.waitForExistence(timeout:5));phone.tap()
        phone.typeText("0543050637"+XCUIKeyboardKey.delete.rawValue+"6")
        XCTAssertEqual(phone.value as? String,"0543050636","Digits stay in typing order inside a right-to-left form")
        capture("qa-he-phone-entry")
        dismissKeyboard("סיום",in:app)
        let save=app.buttons["שמירת איש קשר"];reveal(save,in:app);save.tap()
        XCTAssertTrue(app.buttons["התקשרות QA"].waitForExistence(timeout:5))
        app.buttons["QA, פרטים ותזכורות"].tap()
        XCTAssertTrue(shows("0543050636",in:app))
        try removeOpenPerson("הסרה",in:app)
        XCTAssertTrue(app.buttons["מתחילים עם מישהו אהוב"].exists || app.staticTexts["מתחילים עם מישהו אהוב"].waitForExistence(timeout:5))
    }
}
