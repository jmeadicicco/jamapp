import EventKit
import Foundation

/// Reads Calendar events and Reminders. Both share one `EKEventStore`, as Apple recommends.
final class EventKitConnector {
    static let shared = EventKitConnector()

    let store = EKEventStore()

    /// How far back and ahead calendar events are mirrored into jam.
    var pastDays = 7
    var futureDays = 30

    // MARK: Access

    func accessState(for source: Source) -> AccessState {
        let type: EKEntityType = source == .reminders ? .reminder : .event
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        // Write-only access cannot read anything, so treat it as denied for jam's purposes.
        default: return .denied
        }
    }

    func requestAccess(for source: Source) async throws -> Bool {
        switch source {
        case .calendar: return try await store.requestFullAccessToEvents()
        case .reminders: return try await store.requestFullAccessToReminders()
        case .contacts: return false
        }
    }

    // MARK: Fetch

    func fetchEvents(now: Date = .now) -> [ItemSnapshot] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -pastDays, to: calendar.startOfDay(for: now))!
        let end = calendar.date(byAdding: .day, value: futureDays, to: calendar.startOfDay(for: now))!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)

        return store.events(matching: predicate).map { event in
            var snapshot = ItemSnapshot(
                source: .calendar,
                kind: .event,
                // An event identifier is shared by every occurrence of a repeating event,
                // so the start time is added to keep each occurrence distinct.
                sourceID: "\(event.eventIdentifier ?? event.calendarItemIdentifier)@\(Int(event.startDate.timeIntervalSince1970))",
                title: event.title ?? "Untitled event"
            )
            snapshot.detail = event.notes
            snapshot.location = event.location
            snapshot.start = event.startDate
            snapshot.end = event.endDate
            snapshot.isAllDay = event.isAllDay

            let participants = (event.attendees ?? []) + [event.organizer].compactMap { $0 }
            for participant in participants where !participant.isCurrentUser {
                guard let email = Self.email(from: participant.url) else { continue }
                if !snapshot.participantEmails.contains(email) {
                    snapshot.participantEmails.append(email)
                }
                if let name = participant.name { snapshot.participantNames[email] = name }
            }
            return snapshot
        }
    }

    /// Incomplete reminders plus those completed in the last `pastDays` days.
    func fetchReminders(now: Date = .now) async -> [ItemSnapshot] {
        let recentStart = Calendar.current.date(byAdding: .day, value: -pastDays, to: now)
        async let open = reminders(matching: store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil))
        async let done = reminders(matching: store.predicateForCompletedReminders(
            withCompletionDateStarting: recentStart, ending: now, calendars: nil))
        return await open + done
    }

    private func reminders(matching predicate: NSPredicate) async -> [ItemSnapshot] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                // Convert inside the callback: EKReminder objects should not leave it.
                let snapshots = (reminders ?? []).map { reminder in
                    var snapshot = ItemSnapshot(
                        source: .reminders,
                        kind: .reminder,
                        sourceID: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Untitled reminder"
                    )
                    snapshot.detail = reminder.notes
                    snapshot.start = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
                    snapshot.isAllDay = reminder.dueDateComponents?.hour == nil
                    snapshot.isCompleted = reminder.isCompleted
                    snapshot.end = reminder.completionDate
                    return snapshot
                }
                continuation.resume(returning: snapshots)
            }
        }
    }

    private static func email(from url: URL) -> String? {
        let string = url.absoluteString
        guard string.lowercased().hasPrefix("mailto:") else { return nil }
        let address = String(string.dropFirst("mailto:".count))
        return address.removingPercentEncoding?.lowercased() ?? address.lowercased()
    }
}
