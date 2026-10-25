import Foundation

/// A data source jam can read from. Phase 1 covers the EventKit and Contacts sources.
enum Source: String, CaseIterable, Identifiable, Codable {
    case calendar
    case reminders
    case contacts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        case .contacts: "Contacts"
        }
    }

    var systemImage: String {
        switch self {
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .contacts: "person.crop.circle"
        }
    }

    /// Sources planned for later phases, shown in Settings as not yet available.
    static let planned: [(title: String, systemImage: String, phase: Int)] = [
        ("Health", "heart", 2),
        ("Music", "music.note", 2),
        ("Home", "house", 2),
        ("Mail", "envelope", 4),
    ]
}

/// Permission state for a source, collapsed from each framework's own status type.
enum AccessState: Equatable {
    case notDetermined
    case granted
    case limited
    case denied

    var label: String {
        switch self {
        case .notDetermined: "Not connected"
        case .granted: "Connected"
        case .limited: "Limited access"
        case .denied: "Denied in Settings"
        }
    }

    var canRead: Bool { self == .granted || self == .limited }
}
