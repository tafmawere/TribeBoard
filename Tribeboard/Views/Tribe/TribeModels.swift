import Foundation

enum AvatarSymbol: String, CaseIterable, Hashable, Codable {
    case boltShield = "bolt.shield.fill"
    case hare = "hare.fill"
    case flame = "flame.fill"
    case eye = "eye.fill"
    case star = "star.fill"
    case moonStars = "moon.stars.fill"
    case sun = "sun.max.fill"
    case sparkles = "sparkles"
    case game = "gamecontroller.fill"
    case paint = "paintpalette.fill"

    static func fromLegacyImageName(_ imageName: String?) -> AvatarSymbol? {
        guard let imageName else { return nil }
        switch imageName {
        case "avatar_hero_01": return .boltShield
        case "avatar_hero_02": return .hare
        case "avatar_hero_03": return .flame
        case "avatar_hero_04": return .eye
        case "avatar_hero_05": return .star
        case "avatar_hero_06": return .moonStars
        case "avatar_hero_07": return .sun
        case "avatar_hero_08": return .sparkles
        default:
            return AvatarSymbol(rawValue: imageName)
        }
    }
}

struct MemberAvatarData: Hashable {
    var photoURL: String?
    var imageReference: String?
    var symbol: AvatarSymbol?
    var seed: String
    var name: String

    var initials: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmedName.isEmpty ? "Member" : trimmedName
        return source
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

struct Tribe: Identifiable, Hashable {
    let id: UUID
    var name: String
    var tribeCode: String
    var homeLocationId: UUID?
    var memberIds: [UUID]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        tribeCode: String,
        homeLocationId: UUID? = nil,
        memberIds: [UUID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.tribeCode = tribeCode
        self.homeLocationId = homeLocationId
        self.memberIds = memberIds
        self.createdAt = createdAt
    }
}

enum TribeMemberRole: String, CaseIterable, Hashable {
    case parent
    case child
}

enum MemberPermission: String, CaseIterable, Hashable {
    case admin
    case driver
    case observer

    static func fromLegacyRoles(_ roles: Set<Role>) -> Set<MemberPermission> {
        var mapped: Set<MemberPermission> = []
        if roles.contains(.admin) { mapped.insert(.admin) }
        if roles.contains(.driver) { mapped.insert(.driver) }
        if roles.contains(.observer) { mapped.insert(.observer) }
        return mapped
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
    var avatarURL: String?
    var avatarSeed: String
    var avatarImageName: String?
    var avatarSymbol: AvatarSymbol?
    var role: TribeMemberRole
    var permissions: Set<MemberPermission>
    var memberType: MemberType
    var relationship: String?
    var dateOfBirth: Date?
    var phone: String?
    var roles: Set<Role>
    var isLocationSharingEnabled: Bool
    var isOnline: Bool

    init(
        id: UUID = UUID(),
        fullName: String,
        profileImageURL: URL? = nil,
        avatarURL: String? = nil,
        avatarSeed: String? = nil,
        avatarImageName: String? = nil,
        avatarSymbol: AvatarSymbol? = nil,
        role: TribeMemberRole? = nil,
        permissions: Set<MemberPermission> = [],
        memberType: MemberType,
        relationship: String? = nil,
        dateOfBirth: Date? = nil,
        phone: String? = nil,
        roles: Set<Role> = [],
        isLocationSharingEnabled: Bool = true,
        isOnline: Bool = false
    ) {
        self.id = id
        self.fullName = fullName
        self.avatarURL = avatarURL
        self.avatarSeed = avatarSeed ?? id.uuidString
        if let profileImageURL {
            self.profileImageURL = profileImageURL
        } else if let resolvedURL = AvatarPhotoStore.resolvePhotoURL(from: avatarURL) {
            self.profileImageURL = resolvedURL
        } else {
            self.profileImageURL = nil
        }
        self.avatarImageName = avatarImageName
        self.avatarSymbol = avatarSymbol ?? AvatarSymbol.fromLegacyImageName(avatarImageName)
        self.role = role ?? (memberType == .child ? .child : .parent)
        self.permissions = permissions.isEmpty ? MemberPermission.fromLegacyRoles(roles) : permissions
        self.memberType = memberType
        self.relationship = relationship
        self.dateOfBirth = dateOfBirth
        self.phone = phone
        self.roles = roles
        self.isLocationSharingEnabled = isLocationSharingEnabled
        self.isOnline = isOnline
    }

    var avatar: MemberAvatarData {
        MemberAvatarData(
            photoURL: avatarURL,
            imageReference: avatarImageName,
            symbol: avatarSymbol ?? AvatarSymbol.fromLegacyImageName(avatarImageName),
            seed: avatarSeed,
            name: fullName
        )
    }

    var avatarInitials: String {
        avatar.initials
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

    var age: Int? {
        guard let dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year
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

enum LocationType: String, CaseIterable, Hashable {
    case home
    case school
    case activity
    case custom

    var title: String {
        rawValue.capitalized
    }
}

enum TribeRunStatus: String, CaseIterable, Hashable {
    case scheduled
    case active
    case completed
    case canceled
}

enum ProgressState: String, CaseIterable, Hashable {
    case toPickup
    case pickedUp
    case toDropoff
    case done
}

enum ScheduleType: String, CaseIterable, Hashable {
    case dropoff
    case pickup

    var title: String {
        switch self {
        case .dropoff: return "Drop-off"
        case .pickup: return "Pickup"
        }
    }
}

struct TribeLocation: Identifiable, Hashable {
    let id: UUID
    var name: String
    var address: String
    var type: LocationType
    var tribeId: UUID?
    var childId: UUID?
    var linkedChildIds: [UUID]
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        type: LocationType,
        tribeId: UUID? = nil,
        childId: UUID? = nil,
        linkedChildIds: [UUID] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.type = type
        self.tribeId = tribeId
        self.childId = childId
        self.linkedChildIds = linkedChildIds
        self.notes = notes
    }
}

struct ChildProfile: Identifiable, Hashable {
    let id: UUID
    var memberId: UUID
    var primarySchoolLocationId: UUID
    var activityLocationIds: [UUID]
    var allowedDriverIds: [UUID]
    var trackerMemberIds: [UUID]

    init(
        id: UUID = UUID(),
        memberId: UUID,
        primarySchoolLocationId: UUID,
        activityLocationIds: [UUID] = [],
        allowedDriverIds: [UUID] = [],
        trackerMemberIds: [UUID] = []
    ) {
        self.id = id
        self.memberId = memberId
        self.primarySchoolLocationId = primarySchoolLocationId
        self.activityLocationIds = activityLocationIds
        self.allowedDriverIds = allowedDriverIds
        self.trackerMemberIds = trackerMemberIds
    }
}

struct Routine: Identifiable, Hashable {
    let id: UUID
    var childId: UUID
    var weekdays: Set<Int>
    var dropoffTime: DateComponents
    var pickupTime: DateComponents

    init(
        id: UUID = UUID(),
        childId: UUID,
        weekdays: Set<Int> = [2, 3, 4, 5, 6],
        dropoffTime: DateComponents,
        pickupTime: DateComponents
    ) {
        self.id = id
        self.childId = childId
        self.weekdays = weekdays
        self.dropoffTime = dropoffTime
        self.pickupTime = pickupTime
    }
}

struct ScheduleTemplate: Identifiable, Hashable {
    let id: UUID
    var title: String
    var type: ScheduleType
    var venueId: UUID?
    var venueRuleId: UUID?
    var originLocationId: UUID
    var destinationLocationId: UUID
    var childIds: [UUID]
    var preferredDriverId: UUID?
    var weekdays: Set<Int>
    var timeHour: Int
    var timeMinute: Int
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        title: String,
        type: ScheduleType,
        venueId: UUID? = nil,
        venueRuleId: UUID? = nil,
        originLocationId: UUID,
        destinationLocationId: UUID,
        childIds: [UUID],
        preferredDriverId: UUID?,
        weekdays: Set<Int>,
        timeHour: Int,
        timeMinute: Int,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.venueId = venueId
        self.venueRuleId = venueRuleId
        self.originLocationId = originLocationId
        self.destinationLocationId = destinationLocationId
        self.childIds = childIds
        self.preferredDriverId = preferredDriverId
        self.weekdays = weekdays
        self.timeHour = timeHour
        self.timeMinute = timeMinute
        self.isEnabled = isEnabled
    }
}

struct MobilityRunEvent: Identifiable, Hashable {
    let id: UUID
    var runId: UUID
    var timestamp: Date
    var title: String
    var note: String?

    init(id: UUID = UUID(), runId: UUID, timestamp: Date, title: String, note: String? = nil) {
        self.id = id
        self.runId = runId
        self.timestamp = timestamp
        self.title = title
        self.note = note
    }
}

struct RunInstance: Identifiable, Hashable {
    let id: UUID
    var scheduleTemplateId: UUID?
    var title: String
    var plannedStart: Date
    var originLocationId: UUID
    var destinationLocationId: UUID
    var childIds: [UUID]
    var driverMemberId: UUID?
    var status: TribeRunStatus
    var progress: ProgressState

    init(
        id: UUID = UUID(),
        scheduleTemplateId: UUID? = nil,
        title: String,
        plannedStart: Date,
        originLocationId: UUID,
        destinationLocationId: UUID,
        childIds: [UUID],
        driverMemberId: UUID?,
        status: TribeRunStatus = .scheduled,
        progress: ProgressState = .toPickup
    ) {
        self.id = id
        self.scheduleTemplateId = scheduleTemplateId
        self.title = title
        self.plannedStart = plannedStart
        self.originLocationId = originLocationId
        self.destinationLocationId = destinationLocationId
        self.childIds = childIds
        self.driverMemberId = driverMemberId
        self.status = status
        self.progress = progress
    }
}

struct RunSuggestion: Identifiable, Hashable {
    let id: UUID
    var scheduleTemplateId: UUID
    var title: String
    var proposedStart: Date
    var originName: String
    var destinationName: String
    var childIds: [UUID]
    var childNames: [String]
    var childAvatarImageNames: [String?]
    var driverMemberId: UUID?
    var driverName: String?
    var sourceType: ScheduleType
    var isSuggested: Bool = true
}
