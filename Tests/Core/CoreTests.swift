import XCTest
@testable import EasyCallCore

final class CoreTests:XCTestCase {
    func testInternationalAndLocalNumbers() {
        XCTAssertEqual(PhoneNumber.normalized("+1 (202) 555-0101"),"+12025550101")
        XCTAssertEqual(PhoneNumber.normalized("٠٥٠ ١٢٣ ٤٥٦٧"),"0501234567")
        XCTAssertEqual(PhoneNumber.normalized("+९७२ ५० १२३ ४५६७"),"+972501234567")
        XCTAssertEqual(PhoneNumber.normalized("112"),"112")
    }
    func testRejectsCommandsAndEmbeddedLinks() {
        for input in ["*#21#","tel:1234","1234?foo=bar","1234;9999","1+234","+","1","1234567890123456","abc1234"] { XCTAssertNil(PhoneNumber.url(input),input) }
    }
    func testDuplicateTapDoesNotLaunchSecondCall() {
        var gate = DialGate();let now = Date()
        XCTAssertTrue(gate.admit(now:now));XCTAssertFalse(gate.admit(now:now.addingTimeInterval(0.1)))
        XCTAssertTrue(gate.admit(now:now.addingTimeInterval(2.1)))
        XCTAssertTrue(gate.admit(now:now.addingTimeInterval(-3600)))
    }
    func testTrialExpiresAndClockRollbackDoesNotRenewIt() {
        var s = Snapshot();let now = Date();s.trialStart = now
        XCTAssertTrue(s.trialActive(now:now.addingTimeInterval(13*86400)))
        XCTAssertFalse(s.trialActive(now:now.addingTimeInterval(14*86400)))
        s.latestSeen = now.addingTimeInterval(15*86400)
        XCTAssertFalse(s.trialActive(now:now.addingTimeInterval(2*86400)))
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
