import Foundation

public struct Person: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var phone: String
    public var note: String
    public var photo: Data?
    public var color: Int
    public init(id: UUID = UUID(), name: String, phone: String, note: String = "", photo: Data? = nil, color: Int = 0) {
        self.id = id; self.name = name; self.phone = phone; self.note = note; self.photo = photo; self.color = color
    }
    public var initials: String { name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined() }
}
public extension Person {
    /// What Save stores: a trimmed name, a note of at most 500 characters and the normalized
    /// number. The form keeps showing exactly what was typed; nil means the name or the number
    /// needs attention.
    func preparedForSaving() -> Person? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let number = PhoneNumber.normalized(phone) else { return nil }
        var saved = self
        saved.name = trimmedName
        saved.phone = number
        saved.note = String(note.prefix(500))
        return saved
    }
}
public struct CallReminder: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var personID: UUID
    public var date: Date
}
public struct Snapshot: Codable, Equatable, Sendable {
    public var version = 1
    public var people: [Person] = []
    public var reminders: [CallReminder] = []
    public var largeCards = true
    public var highContrast = false
    public var calmMode = false
    public var latestSeen: Date?
    public init() {}
    public mutating func remove(_ id: UUID) {
        people.removeAll { $0.id == id }; reminders.removeAll { $0.personID == id }
    }
    public func trialActive(start: Date?, now: Date) -> Bool {
        guard let start else { return false }
        let effective = max(now, latestSeen ?? now)
        return effective >= start && effective.timeIntervalSince(start) < 14 * 86400
    }
}
public enum PhoneNumber {
    /// Separators people type or paste between digits: dashes in their several forms (including
    /// the Hebrew maqaf), parentheses, dots, full-width forms, invisible spaces and the direction
    /// marks that Hebrew and Arabic text places around numbers.
    static let separators: Set<Character> = [
        "(", ")", "-", ".", "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2212}", "\u{05BE}",
        "\u{FF08}", "\u{FF09}", "\u{FF0D}", "\u{FF0E}", "\u{00AD}", "\u{200B}", "\u{2060}", "\u{FEFF}",
        "\u{061C}", "\u{200E}", "\u{200F}", "\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}",
        "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}"
    ]
    /// Reject service codes and embedded URL syntax; convert decimal digits from any script.
    /// Runs when a number is saved or dialed, never while someone is still typing it.
    public static func normalized(_ input: String) -> String? {
        var output = ""
        for ch in input {
            if let digit = decimalDigit(ch) { output += String(digit) }
            else if ch == "+" || ch == "\u{FF0B}", output.isEmpty { output += "+" }
            else if ch.isWhitespace || separators.contains(ch) { continue }
            else { return nil }
        }
        let count = output.filter(\.isNumber).count
        guard (2...15).contains(count), output != "+" else { return nil }
        return output
    }
    /// A decimal digit in any script (ASCII, Arabic-Indic, Persian, Devanagari, full-width…).
    /// Superscripts, circled numbers and other numerals are not phone digits.
    static func decimalDigit(_ ch: Character) -> Int? {
        let scalars = ch.unicodeScalars
        guard scalars.count == 1, let scalar = scalars.first, CharacterSet.decimalDigits.contains(scalar),
              let value = ch.wholeNumberValue, (0...9).contains(value) else { return nil }
        return value
    }
    public static func url(_ input: String, faceTime: Bool = false) -> URL? {
        guard let number = normalized(input) else { return nil }
        return URL(string: (faceTime ? "facetime-audio:" : "tel:") + number)
    }
}
public struct DialGate: Sendable {
    private var last: Date?
    public init() {}
    public mutating func admit(now: Date) -> Bool {
        if let last, (0..<2).contains(now.timeIntervalSince(last)) { return false }
        last = now; return true
    }
}
public enum LibraryCodec {
    public static func decode(_ data: Data) throws -> Snapshot {
        let value = try JSONDecoder().decode(Snapshot.self, from: data)
        guard value.version == 1, value.people.count <= 100,
              Set(value.people.map(\.id)).count == value.people.count,
              Set(value.reminders.map(\.id)).count == value.reminders.count,
              value.reminders.allSatisfy({ reminder in value.people.contains { $0.id == reminder.personID } }),
              value.people.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && PhoneNumber.normalized($0.phone) != nil && ($0.photo?.count ?? 0) <= 2_000_000 }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return value
    }
    public static func encode(_ value: Snapshot) throws -> Data { try JSONEncoder().encode(value) }
}
