import Foundation
import SwiftData

/// One human, merged from a contact card and from addresses seen on events (and later mail).
@Model
final class Person {
    /// "contact:<identifier>" for people from Contacts, "email:<address>" otherwise.
    @Attribute(.unique) var key: String
    var name: String
    var contactID: String?
    var emails: [String]
    var phones: [String]
    var birthdayMonth: Int?
    var birthdayDay: Int?
    var updatedAt: Date

    var items: [Item] = []

    init(key: String, name: String) {
        self.key = key
        self.name = name
        self.emails = []
        self.phones = []
        self.updatedAt = .now
    }

    /// Days from `date` until this person's next birthday, or nil if unknown.
    func daysUntilBirthday(from date: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let month = birthdayMonth, let day = birthdayDay else { return nil }
        let today = calendar.startOfDay(for: date)
        let next = calendar.nextDate(
            after: today.addingTimeInterval(-1),
            matching: DateComponents(month: month, day: day),
            matchingPolicy: .nextTimePreservingSmallerComponents
        )
        guard let next else { return nil }
        return calendar.dateComponents([.day], from: today, to: next).day
    }
}

struct PersonSnapshot: Sendable {
    var contactID: String
    var name: String
    var emails: [String]
    var phones: [String]
    var birthdayMonth: Int?
    var birthdayDay: Int?

    var key: String { "contact:\(contactID)" }
}
