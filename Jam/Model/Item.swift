import Foundation
import SwiftData

/// One normalized record from any source: an event, a reminder, and later an email, workout, etc.
@Model
final class Item {
    /// "<source>:<sourceID>", stable across syncs.
    @Attribute(.unique) var key: String
    var sourceRaw: String
    var kindRaw: String
    /// The record's identifier in its source framework, for re-reading or deep-linking.
    var sourceID: String
    var title: String
    var detail: String?
    var location: String?
    var start: Date?
    var end: Date?
    var isAllDay: Bool
    var isCompleted: Bool
    var updatedAt: Date

    @Relationship(inverse: \Person.items) var people: [Person] = []

    init(key: String, source: Source, kind: Kind, sourceID: String, title: String) {
        self.key = key
        self.sourceRaw = source.rawValue
        self.kindRaw = kind.rawValue
        self.sourceID = sourceID
        self.title = title
        self.isAllDay = false
        self.isCompleted = false
        self.updatedAt = .now
    }

    var source: Source? { Source(rawValue: sourceRaw) }
    var kind: Kind? { Kind(rawValue: kindRaw) }

    enum Kind: String, Codable {
        case event
        case reminder
    }
}

/// A plain value a connector produces; the sync engine turns it into an `Item`.
struct ItemSnapshot: Sendable {
    var source: Source
    var kind: Item.Kind
    var sourceID: String
    var title: String
    var detail: String?
    var location: String?
    var start: Date?
    var end: Date?
    var isAllDay = false
    var isCompleted = false
    /// Email addresses of people attached to the record (event attendees, organizer).
    var participantEmails: [String] = []
    var participantNames: [String: String] = [:]

    var key: String { "\(source.rawValue):\(sourceID)" }
}
