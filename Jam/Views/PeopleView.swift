import SwiftData
import SwiftUI

/// Everyone jam knows about, with the events and reminders linked to them.
struct PeopleView: View {
    @Query(sort: \Person.name) private var people: [Person]
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List(filtered) { person in
                NavigationLink(value: person) {
                    VStack(alignment: .leading) {
                        Text(person.name)
                        if !person.items.isEmpty {
                            Text("\(person.items.count) linked items").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("People")
            .navigationDestination(for: Person.self) { PersonDetailView(person: $0) }
            .searchable(text: $search)
        }
    }

    private var filtered: [Person] {
        search.isEmpty ? people : people.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }
}

struct PersonDetailView: View {
    let person: Person

    var body: some View {
        List {
            if !person.emails.isEmpty || !person.phones.isEmpty {
                Section("Contact") {
                    ForEach(person.emails, id: \.self) { Text($0) }
                    ForEach(person.phones, id: \.self) { Text($0) }
                }
            }
            Section("Linked") {
                if person.items.isEmpty {
                    Text("Nothing linked yet.").foregroundStyle(.secondary)
                }
                ForEach(person.items.sorted { ($0.start ?? .distantPast) > ($1.start ?? .distantPast) }) {
                    ItemRow(item: $0)
                }
            }
        }
        .navigationTitle(person.name)
    }
}
