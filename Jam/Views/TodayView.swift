import SwiftData
import SwiftUI

/// Today's events, what is due or overdue, and birthdays in the coming week.
struct TodayView: View {
    @Environment(SyncEngine.self) private var sync
    @Environment(\.modelContext) private var context
    @Query(sort: \Item.start) private var items: [Item]
    @Query(sort: \Person.name) private var people: [Person]

    var body: some View {
        NavigationStack {
            List {
                if !sync.access.values.contains(where: \.canRead) {
                    ContentUnavailableView(
                        "No sources connected",
                        systemImage: "square.stack.3d.up",
                        description: Text("Connect Calendar, Reminders or Contacts in the Sources tab.")
                    )
                }
                section("Events", items: todaysEvents, empty: "Nothing on the calendar today.")
                section("Due", items: dueReminders, empty: "No reminders due.")
                if !upcomingBirthdays.isEmpty {
                    Section("Birthdays this week") {
                        ForEach(upcomingBirthdays) { entry in
                            LabeledContent(entry.person.name, value: entry.days == 0 ? "Today" : "In \(entry.days) d")
                        }
                    }
                }
            }
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            .refreshable { await sync.syncAll(context: context) }
        }
    }

    @ViewBuilder
    private func section(_ title: String, items: [Item], empty: String) -> some View {
        Section(title) {
            if items.isEmpty {
                Text(empty).foregroundStyle(.secondary)
            } else {
                ForEach(items) { ItemRow(item: $0) }
            }
        }
    }

    private var todaysEvents: [Item] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return items.filter { item in
            guard item.kind == .event, let itemStart = item.start else { return false }
            let itemEnd = item.end ?? itemStart
            return itemStart < end && itemEnd > start
        }
    }

    /// Incomplete reminders due today or earlier.
    private var dueReminders: [Item] {
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
        return items.filter { item in
            guard item.kind == .reminder, !item.isCompleted, let due = item.start else { return false }
            return due < endOfToday
        }
    }

    private var upcomingBirthdays: [BirthdayEntry] {
        people
            .compactMap { person in person.daysUntilBirthday().map { BirthdayEntry(person: person, days: $0) } }
            .filter { $0.days <= 7 }
            .sorted { $0.days < $1.days }
    }

    private struct BirthdayEntry: Identifiable {
        let person: Person
        let days: Int
        var id: String { person.key }
    }
}

struct ItemRow: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .strikethrough(item.isCompleted)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String? {
        var parts: [String] = []
        if let start = item.start {
            if item.isAllDay {
                if item.kind == .reminder, start < Calendar.current.startOfDay(for: .now) {
                    parts.append("Overdue since \(start.formatted(.dateTime.month().day()))")
                } else {
                    parts.append(item.kind == .event ? "All day" : "Today")
                }
            } else if let end = item.end, item.kind == .event {
                let time = { (date: Date) in date.formatted(date: .omitted, time: .shortened) }
                parts.append("\(time(start))–\(time(end))")
            } else {
                parts.append(start.formatted(date: .omitted, time: .shortened))
            }
        }
        if let location = item.location, !location.isEmpty { parts.append(location) }
        if !item.people.isEmpty {
            parts.append(item.people.prefix(3).map(\.name).joined(separator: ", "))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
