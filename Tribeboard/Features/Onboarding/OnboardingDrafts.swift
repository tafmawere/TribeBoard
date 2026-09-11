import Foundation

enum OnboardingPathChoice: String, Codable, CaseIterable {
    case setup
    case join
}

enum OnboardingJoinResultStatus: String, Codable {
    case active
    case pending
}

struct ResolvedLocationDraft: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var address: String
    var latitude: Double?
    var longitude: Double?
    var placeId: String?

    init(
        id: UUID = UUID(),
        title: String,
        address: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.placeId = placeId
    }
}

struct OnboardingProfileDraft: Codable, Hashable {
    var firstName: String
    var lastName: String
    var displayName: String
    var avatarType: AvatarType
    var avatarKey: String?
    var avatarURL: String?

    init(
        firstName: String = "",
        lastName: String = "",
        displayName: String = "",
        avatarType: AvatarType = .preset,
        avatarKey: String? = AvatarPresetCatalog.defaultAdultKey,
        avatarURL: String? = nil
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.displayName = displayName
        self.avatarType = avatarType
        self.avatarKey = avatarKey
        self.avatarURL = avatarURL
    }

    var avatarIdentity: TribeAvatarIdentity {
        TribeAvatarIdentity(
            avatarType: avatarType,
            avatarKey: avatarKey,
            avatarURL: avatarURL,
            displayName: resolvedDisplayName
        )
    }

    var resolvedDisplayName: String {
        let display = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !display.isEmpty { return display }
        let parts = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }
}

enum OnboardingHomeLocationPhase: String, Codable {
    case search
    case confirm
}

struct TribeDraft: Codable, Hashable {
    var tribeName: String
}

struct SchoolDraft: Codable, Hashable {
    var id: UUID
    var schoolName: String
    var location: ResolvedLocationDraft?
    var defaultStartHour: Int?
    var defaultStartMinute: Int?
    var defaultEndHour: Int?
    var defaultEndMinute: Int?

    init(
        id: UUID = UUID(),
        schoolName: String = "",
        location: ResolvedLocationDraft? = nil,
        defaultStartHour: Int? = nil,
        defaultStartMinute: Int? = nil,
        defaultEndHour: Int? = nil,
        defaultEndMinute: Int? = nil
    ) {
        self.id = id
        self.schoolName = schoolName
        self.location = location
        self.defaultStartHour = defaultStartHour
        self.defaultStartMinute = defaultStartMinute
        self.defaultEndHour = defaultEndHour
        self.defaultEndMinute = defaultEndMinute
    }
}

struct RoutineDayDraft: Identifiable, Codable, Hashable {
    let id: UUID
    var weekday: Weekday
    var isEnabled: Bool
    var dropoffHour: Int
    var dropoffMinute: Int
    var pickupHour: Int
    var pickupMinute: Int

    init(
        id: UUID = UUID(),
        weekday: Weekday,
        isEnabled: Bool,
        dropoffHour: Int,
        dropoffMinute: Int,
        pickupHour: Int,
        pickupMinute: Int
    ) {
        self.id = id
        self.weekday = weekday
        self.isEnabled = isEnabled
        self.dropoffHour = dropoffHour
        self.dropoffMinute = dropoffMinute
        self.pickupHour = pickupHour
        self.pickupMinute = pickupMinute
    }
}

struct RoutineDraft: Codable, Hashable {
    var days: [RoutineDayDraft]
}

struct ActivityDraft: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var weekday: Weekday
    var hour: Int
    var minute: Int
    var atSchool: Bool
    var location: ResolvedLocationDraft?

    init(
        id: UUID = UUID(),
        title: String,
        weekday: Weekday,
        hour: Int,
        minute: Int,
        atSchool: Bool = false,
        location: ResolvedLocationDraft? = nil
    ) {
        self.id = id
        self.title = title
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
        self.atSchool = atSchool
        self.location = location
    }
}

struct ChildDraft: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var legalName: String
    var dateOfBirth: Date?
    var gradeOrClass: String
    var schoolId: UUID?
    var school: SchoolDraft
    var routine: RoutineDraft
    var activities: [ActivityDraft]

    init(
        id: UUID = UUID(),
        displayName: String = "",
        legalName: String = "",
        dateOfBirth: Date? = nil,
        gradeOrClass: String = "",
        schoolId: UUID? = nil,
        school: SchoolDraft = SchoolDraft(),
        routine: RoutineDraft = RoutineDraft(days: RoutineDayDraft.defaultSchoolWeek),
        activities: [ActivityDraft] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.legalName = legalName
        self.dateOfBirth = dateOfBirth
        self.gradeOrClass = gradeOrClass
        self.schoolId = schoolId
        self.school = school
        self.routine = routine
        self.activities = activities
    }

    var completedSchoolStep: Bool {
        schoolId != nil
            && !school.schoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && school.location != nil
    }

    var completedRoutineStep: Bool {
        routine.days.contains(where: \.isEnabled)
    }
}

struct SupportPersonDraft: Identifiable, Codable, Hashable {
    let id: UUID
    var email: String
    var accessRole: String
    var relationshipLabel: String

    init(
        id: UUID = UUID(),
        email: String = "",
        accessRole: String = "observer",
        relationshipLabel: String = ""
    ) {
        self.id = id
        self.email = email
        self.accessRole = accessRole
        self.relationshipLabel = relationshipLabel
    }
}

struct PendingEmailInvitePresentation: Codable, Hashable {
    let inviteId: UUID
    let householdId: UUID
    let householdName: String
    let inviteeEmail: String
    let accessRole: String
    let relationship: String?
    let pendingInviteCount: Int

    var displayAccessRole: String {
        switch accessRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "driver":
            return "Driver"
        case "organiser", "organizer":
            return "Organiser"
        default:
            return "Observer"
        }
    }

    var displayRelationship: String {
        let trimmed = relationship?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Family member" : trimmed
    }
}

extension RoutineDayDraft {
    static let defaultSchoolWeek: [RoutineDayDraft] = [
        .init(weekday: .monday, isEnabled: true, dropoffHour: 7, dropoffMinute: 30, pickupHour: 14, pickupMinute: 30),
        .init(weekday: .tuesday, isEnabled: true, dropoffHour: 7, dropoffMinute: 30, pickupHour: 14, pickupMinute: 30),
        .init(weekday: .wednesday, isEnabled: true, dropoffHour: 7, dropoffMinute: 30, pickupHour: 14, pickupMinute: 30),
        .init(weekday: .thursday, isEnabled: true, dropoffHour: 7, dropoffMinute: 30, pickupHour: 14, pickupMinute: 30),
        .init(weekday: .friday, isEnabled: true, dropoffHour: 7, dropoffMinute: 30, pickupHour: 14, pickupMinute: 30),
        .init(weekday: .saturday, isEnabled: false, dropoffHour: 9, dropoffMinute: 0, pickupHour: 12, pickupMinute: 0),
        .init(weekday: .sunday, isEnabled: false, dropoffHour: 9, dropoffMinute: 0, pickupHour: 12, pickupMinute: 0)
    ]
}
