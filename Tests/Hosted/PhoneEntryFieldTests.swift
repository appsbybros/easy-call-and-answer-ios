import XCTest
import SwiftUI
import UIKit
@testable import EasyCall

private final class Store { var text = "" }

/// QA ISSUE-002: on an iPad with a Hebrew keyboard, digits typed in the contact form's phone
/// field did not show and contacts could not be added reliably.
@MainActor final class PhoneEntryFieldTests: XCTestCase {
    func testIPadOpensADockedDigitsKeyboardAndIPhoneKeepsThePhoneKeypad() {
        XCTAssertEqual(PhoneEntryField.keyboardType(for:.pad),.numbersAndPunctuation)
        XCTAssertEqual(PhoneEntryField.keyboardType(for:.phone),.phonePad)
        let field=PhoneEntryField(frame:.zero)
        XCTAssertEqual(field.keyboardType,PhoneEntryField.keyboardType(for:UIDevice.current.userInterfaceIdiom))
        XCTAssertNotNil(field.inputAccessoryView,"Phone keypads have no Return key; Done closes them")
        if #available(iOS 26.0, *) {
            if field.responds(to:#selector(getter:UITextInputTraits.allowsNumberPadPopover)) {
                XCTAssertFalse(field.allowsNumberPadPopover,"The floating number pad lost digits inside the contact sheet")
            }
        }
    }
    func testNumberStaysLeftToRightInsideRightToLeftLayouts() {
        let field=PhoneEntryField(frame:.zero)
        field.semanticContentAttribute = .forceRightToLeft
        XCTAssertEqual(field.semanticContentAttribute,.forceLeftToRight)
        field.font=UIFont.preferredFont(forTextStyle:.title2)
        field.keepLeftToRight()
        XCTAssertEqual(field.textAlignment,.left)
        let paragraph=field.defaultTextAttributes[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(paragraph?.baseWritingDirection,NSWritingDirection.leftToRight)
        XCTAssertEqual(field.autocorrectionType,.no,"Suggestions must not replace typed digits")
        XCTAssertEqual(field.smartDashesType,.no)
        XCTAssertEqual(field.smartInsertDeleteType,.no)
    }
    func testTypedTextIsStoredExactlyAsTypedAndEditsAreKept() {
        let store=Store()
        let coordinator=PhoneNumberField.Coordinator(text:Binding(get:{store.text},set:{store.text=$0}))
        let field=PhoneEntryField(frame:.zero)
        field.onTextChange={coordinator.received($0)}
        // Digits from the number row, an Arabic-Indic keyboard and separators arrive unchanged,
        // including deletions; the field is never reformatted while someone types.
        for typed in ["0","05","05٤","05٤ 3","05٤ 3-","05٤ 3","05"] {
            field.text=typed
            field.sendActions(for:.editingChanged)
            XCTAssertEqual(store.text,typed)
            field.show(store.text)
            XCTAssertEqual(field.text,typed,"Showing the stored text again must not disturb typing")
        }
        store.text="+972543050636"
        field.show(store.text)
        XCTAssertEqual(field.text,"+972543050636","A number chosen from Contacts appears in the field")
        // The clear button or the keyboard's undo key may report only a text-change notification.
        field.text=""
        NotificationCenter.default.post(name:UITextField.textDidChangeNotification,object:field)
        XCTAssertEqual(store.text,"","A cleared field must not save the previous number")
    }
}
