import Foundation
import Observation
import SwiftData

/// Pulls every connected source into the local store. Runs on the main actor because
/// SwiftData's main context lives there; connectors do their slow work off it.
@MainActor
@Observable
final class SyncEngine {
    private(set) var access: [Source: AccessState] = [:]
    private(set) var isSyncing = false
    private(set) var lastSync: Date?
    private(set) var lastError: String?

    private let eventKit = EventKitConnector.shared
    private let contacts = ContactsConnector.shared

    init() {
        refreshAccess()
    }

    func refreshAccess() {
        for source in Source.allCases {
            access[source] = switch source {
            case .calendar, .reminders: eventKit.accessState(for: source)
            case .contacts: contacts.accessState()
            }
        }
    }

    func connect(_ source: Source, context: ModelContext) async {
        do {
            switch source {
            case .calendar, .reminders: _ = try await eventKit.requestAccess(for: source)
            case .contacts: _ = try await contacts.requestAccess()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refreshAccess()
        await syncAll(context: context)
    }

    /// Syncs Contacts first so that event attendees can be matched to known people.
    func syncAll(context: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        refreshAccess()
        lastError = nil

        do {
            if access[.contacts]?.canRead == true {
                upsertPeople(try await contacts.fetchPeople(), context: context)
            }
            if access[.calendar]?.canRead == true {
                upsertItems(eventKit.fetchEvents(), source: .calendar, context: context)
            }
            if access[.reminders]?.canRead == true {
                upsertItems(await eventKit.fetchReminders(), source: .reminders, context: context)
            }
            try context.save()
            lastSync = .now
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Upserts

    private func upsertPeople(_ snapshots: [PersonSnapshot], context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        var byKey = Dictionary(existing.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()

        for snapshot in snapshots {
            seen.insert(snapshot.key)
            let person = byKey[snapshot.key] ?? {
                let person = Person(key: snapshot.key, name: snapshot.name)
                context.insert(person)
                byKey[snapshot.key] = person
                return person
            }()
            person.name = snapshot.name
            person.contactID = snapshot.contactID
            person.emails = snapshot.emails
            person.phones = snapshot.phones
            person.birthdayMonth = snapshot.birthdayMonth
            person.birthdayDay = snapshot.birthdayDay
            person.updatedAt = .now

            // A contact now covers any email-only person created earlier from an attendee.
            for email in snapshot.emails {
                if let stray = byKey["email:\(email)"] {
                    person.items.append(contentsOf: stray.items)
                    context.delete(stray)
                    byKey["email:\(email)"] = nil
                }
            }
        }

        // Remove contacts that were deleted from the address book.
        for person in existing where person.contactID != nil && !seen.contains(person.key) {
            context.delete(person)
        }
    }

    /// Mirrors one source: inserts new records, updates changed ones, deletes ones that disappeared.
    private func upsertItems(_ snapshots: [ItemSnapshot], source: Source, context: ModelContext) {
        let raw = source.rawValue
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.sourceRaw == raw })
        let existing = (try? context.fetch(descriptor)) ?? []
        var byKey = Dictionary(existing.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var peopleByEmail = emailIndex(context: context)
        var seen = Set<String>()

        for snapshot in snapshots {
            seen.insert(snapshot.key)
            let item = byKey[snapshot.key] ?? {
                let item = Item(key: snapshot.key, source: source, kind: snapshot.kind,
                                sourceID: snapshot.sourceID, title: snapshot.title)
                context.insert(item)
                byKey[snapshot.key] = item
                return item
            }()
            item.title = snapshot.title
            item.detail = snapshot.detail
            item.location = snapshot.location
            item.start = snapshot.start
            item.end = snapshot.end
            item.isAllDay = snapshot.isAllDay
            item.isCompleted = snapshot.isCompleted
            item.updatedAt = .now
            var people: [Person] = []
            for email in snapshot.participantEmails {
                if let person = peopleByEmail[email] {
                    people.append(person)
                } else {
                    let person = Person(key: "email:\(email)", name: snapshot.participantNames[email] ?? email)
                    person.emails = [email]
                    context.insert(person)
                    peopleByEmail[email] = person
                    people.append(person)
                }
            }
            item.people = people
        }

        for item in existing where !seen.contains(item.key) {
            context.delete(item)
        }
    }

    private func emailIndex(context: ModelContext) -> [String: Person] {
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        var index: [String: Person] = [:]
        for person in people {
            for email in person.emails where index[email] == nil {
                index[email] = person
            }
        }
        return index
    }
}
