import XCTest
@testable import EasyCallCore

final class CoreTests:XCTestCase {
    func testInternationalAndLocalNumbers() {
        XCTAssertEqual(PhoneNumber.normalized("+1 (202) 555-0101"),"+12025550101")
        XCTAssertEqual(PhoneNumber.normalized("٠٥٠ ١٢٣ ٤٥٦٧"),"0501234567")
        XCTAssertEqual(PhoneNumber.normalized("+९७२ ५० १२३ ४५६७"),"+972501234567")
        XCTAssertEqual(PhoneNumber.normalized("112"),"112")
        XCTAssertEqual(PhoneNumber.normalized("\u{200E}+972 50 1234567\u{200F}"),"+972501234567")
    }
    func testRejectsCommandsAndEmbeddedLinks() {
        for input in ["*#21#","tel:1234","1234?foo=bar","1234;9999","1+234","+","1","1234567890123456","abc1234"] { XCTAssertNil(PhoneNumber.url(input),input) }
    }
    func testDigitsFromHebrewArabicAndIPadKeyboardsAndPastedNumbers() {
        // Persian (Extended Arabic-Indic) digits.
        XCTAssertEqual(PhoneNumber.normalized("\u{06F0}\u{06F5}\u{06F4} \u{06F3}\u{06F0}\u{06F5} \u{06F0}\u{06F6}\u{06F3}\u{06F6}"),"0543050636")
        // Arabic-Indic digits wrapped in Arabic letter marks.
        XCTAssertEqual(PhoneNumber.normalized("\u{061C}٠٥٤\u{061C}-٣٠٥-٠٦٣٦"),"0543050636")
        // A number pasted from right-to-left text: embedding marks and non-breaking hyphens.
        XCTAssertEqual(PhoneNumber.normalized("\u{202A}+972 54\u{2011}305\u{2011}0636\u{202C}"),"+972543050636")
        // Hebrew maqaf, minus sign and em dash between groups.
        XCTAssertEqual(PhoneNumber.normalized("054\u{05BE}305\u{05BE}0636"),"0543050636")
        XCTAssertEqual(PhoneNumber.normalized("054\u{2212}305\u{2014}0636"),"0543050636")
        // Full-width plus and digits.
        XCTAssertEqual(PhoneNumber.normalized("\u{FF0B}\u{FF19}\u{FF17}\u{FF12} \u{FF15}\u{FF14}"),"+97254")
        // No-break and zero-width spaces.
        XCTAssertEqual(PhoneNumber.normalized("054\u{00A0}305\u{200B}0636"),"0543050636")
    }
    func testRejectsNumeralsThatAreNotPhoneDigits() {
        for input in ["054\u{00B2}305063","\u{2460}\u{2461}\u{2462}\u{2463}","0543050636+","054 305 0636 #","054-305-063X"] {
            XCTAssertNil(PhoneNumber.normalized(input),input)
        }
    }
    func testSaveNormalizesTheStoredCopyOnly() throws {
        let typed=Person(name:"  דנה \n",phone:"٠٥٤-٣٠٥-٠٦٣٦",note:String(repeating:"א",count:600))
        let saved=try XCTUnwrap(typed.preparedForSaving())
        XCTAssertEqual(saved.name,"דנה")
        XCTAssertEqual(saved.phone,"0543050636")
        XCTAssertEqual(saved.note.count,500)
        XCTAssertEqual(saved.id,typed.id)
        XCTAssertEqual(typed.phone,"٠٥٤-٣٠٥-٠٦٣٦","What was typed stays untouched until it is saved")
        XCTAssertNil(Person(name:" \n",phone:"0543050636").preparedForSaving())
        XCTAssertNil(Person(name:"Dana",phone:"054 305 06a6").preparedForSaving())
    }
    func testDuplicateTapDoesNotLaunchSecondCall() {
        var gate = DialGate();let now = Date()
        XCTAssertTrue(gate.admit(now:now));XCTAssertFalse(gate.admit(now:now.addingTimeInterval(0.1)))
        XCTAssertTrue(gate.admit(now:now.addingTimeInterval(2.1)))
        XCTAssertTrue(gate.admit(now:now.addingTimeInterval(-3600)))
    }
    func testTrialExpiresAndClockRollbackDoesNotRenewIt() {
        var s = Snapshot();let now = Date()
        XCTAssertFalse(s.trialActive(start:nil,now:now))
        XCTAssertFalse(s.trialActive(start:now,now:now.addingTimeInterval(-1)))
        XCTAssertTrue(s.trialActive(start:now,now:now.addingTimeInterval(13*86400)))
        XCTAssertFalse(s.trialActive(start:now,now:now.addingTimeInterval(14*86400)))
        s.latestSeen = now.addingTimeInterval(15*86400)
        XCTAssertFalse(s.trialActive(start:now,now:now.addingTimeInterval(2*86400)))
    }
    func testDeleteOnlyRemovesRelatedReminders() {
        var s = Snapshot();let one = Person(name:"One",phone:"1234"),two = Person(name:"Two",phone:"5678")
        s.people = [one,two];s.reminders = [.init(personID:one.id,date:Date()),.init(personID:two.id,date:Date())]
        s.remove(one.id);XCTAssertEqual(s.people,[two]);XCTAssertEqual(s.reminders.map(\.personID),[two.id])
    }
    func testRoundTripAndInvalidBackup() throws {
        var s = Snapshot();s.people = [.init(name:"דנה",phone:"0501234567",note:"הערה")]
        XCTAssertEqual(try LibraryCodec.decode(LibraryCodec.encode(s)),s)
        s.people.append(s.people[0]);XCTAssertThrowsError(try LibraryCodec.decode(LibraryCodec.encode(s)))
        XCTAssertThrowsError(try LibraryCodec.decode(Data("not json".utf8)))
    }
}
