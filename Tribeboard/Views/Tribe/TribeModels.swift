import Foundation

struct Tribe: Identifiable, Hashable {
    let id: UUID
    var name: String
    var tribeCode: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        tribeCode: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.tribeCode = tribeCode
        self.createdAt = createdAt
    }
}

enum MemberType: String, CaseIterable, Identifiable, Hashable {
    case adult = "Adult"
    case child = "Child"

    var id: String { rawValue }
}

enum Role: String, CaseIterable, Identifiable, Hashable {
    case admin = "Admin"
    case driver = "Driver"
    case observer = "Observer"
    case passenger = "Passenger"
    case parent = "Parent"
    case child = "Child"

    var id: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .admin: return 0
        case .driver: return 1
        case .observer: return 2
        case .parent: return 3
        case .child: return 4
        case .passenger: return 5
        }
    }
}

struct TribeMember: Identifiable, Hashable {
    let id: UUID
    var fullName: String
    var profileImageURL: URL?
    var memberType: MemberType
    var relationship: String?
    var age: Int?
    var phone: String?
    var roles: Set<Role>
    var isLocationSharingEnabled: Bool
    var isOnline: Bool

    init(
        id: UUID = UUID(),
        fullName: String,
        profileImageURL: URL? = nil,
        memberType: MemberType,
        relationship: String? = nil,
        age: Int? = nil,
        phone: String? = nil,
        roles: Set<Role> = [],
        isLocationSharingEnabled: Bool = true,
        isOnline: Bool = false
    ) {
        self.id = id
        self.fullName = fullName
        self.profileImageURL = profileImageURL
        self.memberType = memberType
        self.relationship = relationship
        self.age = age
        self.phone = phone
        self.roles = roles
        self.isLocationSharingEnabled = isLocationSharingEnabled
        self.isOnline = isOnline
    }

    var roleBadges: [String] {
        roles
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { $0.rawValue.uppercased() }
    }

    var derivedPermissions: [String] {
        TribeMember.permissions(for: roles)
    }

    var subtitle: String {
        if memberType == .adult {
            return relationship ?? "Adult"
        }
        if let age {
            return "Age \(age)"
        }
        return "Child"
    }

    var isDriver: Bool {
        roles.contains(.driver)
    }

    static func permissions(for roles: Set<Role>) -> [String] {
        var permissions: Set<String> = []
        let mapping: [Role: [String]] = [
            .admin: ["Manage tribe members", "Assign roles", "Create and edit runs"],
            .driver: ["Start and drive runs", "Share live trip location"],
            .observer: ["View run status", "Track family activity"],
            .passenger: ["View assigned runs"],
            .parent: ["Create family schedules"],
            .child: ["View personal itinerary"]
        ]

        for role in roles {
            mapping[role, default: []].forEach { permissions.insert($0) }
        }

        return permissions.sorted()
    }
}
