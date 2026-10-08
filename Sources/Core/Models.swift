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
    /// Reject service codes and embedded URL syntax; convert decimal digits from any script.
    public static func normalized(_ input: String) -> String? {
        var output = ""
        for ch in input {
            if let digit = ch.wholeNumberValue, (0...9).contains(digit) { output += String(digit) }
            else if ch == "+", output.isEmpty { output += "+" }
            else if ch.isWhitespace || "()-–.\u{200E}\u{200F}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}".contains(ch) { continue }
            else { return nil }
        }
        let count = output.filter(\.isNumber).count
        guard (2...15).contains(count), output != "+" else { return nil }
        return output
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
