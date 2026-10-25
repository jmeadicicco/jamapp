import Contacts
import Foundation

/// Reads the address book into `PersonSnapshot`s.
final class ContactsConnector {
    static let shared = ContactsConnector()

    let store = CNContactStore()

    func accessState() -> AccessState {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized: return .granted
        case .limited: return .limited
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func requestAccess() async throws -> Bool {
        try await store.requestAccess(for: .contacts)
    }

    /// Enumerates every contact jam can see. Runs off the main thread because enumeration blocks.
    func fetchPeople() async throws -> [PersonSnapshot] {
        let store = self.store
        return try await Task.detached(priority: .utility) {
            let keys: [CNKeyDescriptor] = [
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactBirthdayKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor,
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var people: [PersonSnapshot] = []
            try store.enumerateContacts(with: request) { contact, _ in
                let name = CNContactFormatter.string(from: contact, style: .fullName)
                    ?? (contact.organizationName.isEmpty ? nil : contact.organizationName)
                guard let name else { return }
                people.append(PersonSnapshot(
                    contactID: contact.identifier,
                    name: name,
                    emails: contact.emailAddresses.map { ($0.value as String).lowercased() },
                    phones: contact.phoneNumbers.map { $0.value.stringValue },
                    birthdayMonth: contact.birthday?.month,
                    birthdayDay: contact.birthday?.day
                ))
            }
            return people
        }.value
    }
}
