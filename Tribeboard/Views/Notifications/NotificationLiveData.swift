import Foundation

enum NotificationInboxBootstrap {
    /// Live inbox starts empty. Preview/DEBUG callers pass `NotificationMockData` explicitly.
    static let liveItems: [NotificationInboxItem] = []
}

enum NotificationLiveContacts {
    static func from(people: [BackendHouseholdPerson]) -> (drivers: [ContactShortcut], parents: [ContactShortcut]) {
        var drivers: [ContactShortcut] = []
        var parents: [ContactShortcut] = []
        for person in people {
            let name = person.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let phone = person.phone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty, !phone.isEmpty else { continue }
            let roleBlob = "\(person.role) \(person.relationship ?? "")".lowercased()
            if roleBlob.contains("child") { continue }
            let shortcut = ContactShortcut(
                id: person.id,
                role: person.isDriver ? "Driver" : "Family",
                name: name,
                phone: phone
            )
            if person.isDriver {
                drivers.append(shortcut)
            } else {
                parents.append(shortcut)
            }
        }
        return (drivers, parents)
    }
}
