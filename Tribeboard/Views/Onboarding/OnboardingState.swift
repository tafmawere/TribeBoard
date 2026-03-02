import SwiftUI
import Combine

enum OnboardingWeekday: String, CaseIterable, Hashable {
    case monday = "Mon"
    case tuesday = "Tue"
    case wednesday = "Wed"
    case thursday = "Thu"
    case friday = "Fri"
    case saturday = "Sat"
    case sunday = "Sun"

    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    static let calendarOrder: [OnboardingWeekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
    ]

    static func sorted(_ days: Set<OnboardingWeekday>) -> [OnboardingWeekday] {
        calendarOrder.filter { days.contains($0) }
    }

    static func joinedLabel(_ days: Set<OnboardingWeekday>, separator: String = "/") -> String {
        sorted(days).map(\.rawValue).joined(separator: separator)
    }
}

enum VenueType: String, CaseIterable, Hashable {
    case school = "School"
    case sport = "Sport"
    case tutor = "Tutor"
    case family = "Family"
    case other = "Other"
}

enum TripMode: String, CaseIterable, Hashable {
    case roundTrip = "Round trip"
    case dropOffOnly = "Drop-off only"
    case pickupOnly = "Pickup only"

    var runsPerDay: Int {
        switch self {
        case .roundTrip: return 2
        case .dropOffOnly, .pickupOnly: return 1
        }
    }
}

struct Place: Hashable {
    var name: String
    var formattedAddress: String
    var latitude: Double
    var longitude: Double
    var placeId: String?
}

struct Venue: Identifiable, Hashable {
    let id: UUID
    var type: VenueType
    var label: String
    var place: Place
    var ruleIds: [UUID]
}

struct VenueRule: Identifiable, Hashable {
    let id: UUID
    var venueId: UUID
    var weekdays: Set<OnboardingWeekday>
    var dropOffTime: DateComponents?
    var pickupTime: DateComponents?
    var tripMode: TripMode

    var isValid: Bool {
        guard !weekdays.isEmpty else { return false }
        switch tripMode {
        case .roundTrip:
            guard let drop = dropOffTime, let pick = pickupTime else { return false }
            guard let dh = drop.hour, let dm = drop.minute, let ph = pick.hour, let pm = pick.minute else { return false }
            return (ph * 60 + pm) > (dh * 60 + dm)
        case .dropOffOnly:
            guard let drop = dropOffTime else { return false }
            return drop.hour != nil && drop.minute != nil
        case .pickupOnly:
            guard let pick = pickupTime else { return false }
            return pick.hour != nil && pick.minute != nil
        }
    }
}

struct OnboardingChildDraft: Identifiable, Hashable {
    let id: UUID
    var name: String
    var dateOfBirth: Date?
    var avatarImageName: String
    var avatarId: String?
    var avatarSymbol: AvatarSymbol?
    var avatarURL: String?
    var avatarSeed: String
    var venues: [Venue]
    var venueRules: [VenueRule]

    init(
        id: UUID = UUID(),
        name: String = "",
        dateOfBirth: Date? = nil,
        avatarImageName: String = "",
        avatarId: String? = nil,
        avatarSymbol: AvatarSymbol? = nil,
        avatarURL: String? = nil,
        avatarSeed: String = UUID().uuidString,
        venues: [Venue] = [],
        venueRules: [VenueRule] = []
    ) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.avatarImageName = avatarImageName
        self.avatarId = avatarId
        self.avatarSymbol = avatarSymbol ?? AvatarSymbol.fromLegacyImageName(avatarId ?? avatarImageName)
        self.avatarURL = avatarURL
        self.avatarSeed = avatarSeed
        self.venues = venues
        self.venueRules = venueRules
    }

    var isComplete: Bool {
        !venues.isEmpty &&
        venueRules.contains { rule in
            venues.contains(where: { $0.id == rule.venueId }) && rule.isValid
        }
    }

    var isSetupComplete: Bool { isComplete }

    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    var runsPerWeek: Int {
        venueRules.reduce(0) { partial, rule in
            guard rule.isValid else { return partial }
            return partial + (rule.weekdays.count * rule.tripMode.runsPerDay)
        }
    }

    var avatar: MemberAvatarData {
        MemberAvatarData(
            photoURL: avatarURL,
            imageReference: (avatarId ?? avatarImageName).nilIfEmpty,
            symbol: avatarSymbol ?? AvatarSymbol.fromLegacyImageName((avatarId ?? avatarImageName).nilIfEmpty),
            seed: avatarSeed,
            name: name
        )
    }
}

struct Adult: Identifiable, Hashable {
    enum AccessLevel: String, CaseIterable, Hashable {
        case admin
        case standard
        case observer
    }

    enum RelationshipTag: String, CaseIterable, Hashable {
        case parent = "Parent"
        case guardian = "Guardian"
        case helper = "Helper"
        case relative = "Relative"
    }

    let id: UUID
    var name: String
    var relationshipTag: RelationshipTag?
    var accessLevel: AccessLevel
    var canDrive: Bool
    var avatarImageName: String
    var avatarSymbol: AvatarSymbol?
    var avatarURL: String?
    var avatarSeed: String

    var avatar: MemberAvatarData {
        MemberAvatarData(
            photoURL: avatarURL,
            imageReference: avatarImageName.nilIfEmpty,
            symbol: avatarSymbol ?? AvatarSymbol.fromLegacyImageName(avatarImageName.nilIfEmpty),
            seed: avatarSeed,
            name: name
        )
    }
}

@MainActor
final class OnboardingState: ObservableObject {
    enum EntryChoice {
        case create
        case join
    }

    enum Step: Int, CaseIterable {
        case welcome
        case createTribe
        case joinTribe
        case setHome
        case addAdults
        case addChildren
        case childSetup
        case review

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .createTribe: return "Create Tribe"
            case .joinTribe: return "Join Tribe"
            case .setHome: return "Set Home"
            case .addAdults: return "Add Adults"
            case .addChildren: return "Add Children"
            case .childSetup: return "Add Venue"
            case .review: return "Review & Finish"
            }
        }
    }

    @Published var step: Step = .welcome
    @Published var entryChoice: EntryChoice = .create
    @Published var tribeName = ""
    @Published var familyCode = ""
    @Published var homeLabel = "Home"
    @Published var homeAddress = ""
    @Published var homeAddressTitle = ""
    @Published var homeAddressSubtitle = ""
    @Published var homeLatitude: Double?
    @Published var homeLongitude: Double?
    @Published var adults: [Adult] = [
        Adult(
            id: UUID(),
            name: "You",
            relationshipTag: nil,
            accessLevel: .admin,
            canDrive: false,
            avatarImageName: "",
            avatarSymbol: nil,
            avatarURL: nil,
            avatarSeed: UUID().uuidString
        )
    ]
    @Published var children: [OnboardingChildDraft] = []
    @Published var selectedChildID: UUID?

    var selectedChildIndex: Int? {
        guard let selectedChildID else { return nil }
        return children.firstIndex(where: { $0.id == selectedChildID })
    }

    var selectedChild: OnboardingChildDraft? {
        guard let idx = selectedChildIndex else { return nil }
        return children[idx]
    }

    var canContinueFromCurrentStep: Bool {
        switch step {
        case .welcome:
            return true
        case .createTribe:
            return true
        case .joinTribe:
            return !familyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .setHome:
            return !homeAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .addAdults:
            guard let primary = adults.first else { return false }
            let primaryName = primary.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return !primaryName.isEmpty && primary.accessLevel == .admin
        case .addChildren:
            return children.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .childSetup:
            return selectedChild?.isComplete == true
        case .review:
            return canFinish
        }
    }

    var canFinish: Bool {
        let hasHome = !homeAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasHome && readyChildrenCount > 0
    }

    var weeklyRunsToCreate: Int {
        children
            .filter(\.isSetupComplete)
            .reduce(0) { $0 + $1.runsPerWeek }
    }

    var scheduleTemplatesToCreate: Int {
        children
            .filter(\.isSetupComplete)
            .reduce(0) { partial, child in
                let validRules = child.venueRules.filter(\.isValid)
                let templateCount = validRules.reduce(0) { count, rule in
                    count + ((rule.tripMode == .roundTrip) ? 2 : 1)
                }
                return partial + templateCount
            }
    }

    var readyChildrenCount: Int {
        children.filter(\.isSetupComplete).count
    }

    var hasUnreadyChildren: Bool {
        children.contains { !$0.isSetupComplete }
    }

    var hasDriver: Bool {
        adults.contains { $0.canDrive }
    }

    func goToCreateTribe() {
        entryChoice = .create
        step = .createTribe
    }

    func goToJoinTribe() {
        entryChoice = .join
        step = .joinTribe
    }

    func continueFromCreateTribe() {
        entryChoice = .create
        step = .setHome
    }

    func continueFromJoinTribe() {
        guard canContinueFromCurrentStep else { return }
        entryChoice = .join
        step = .setHome
    }

    func continueFromSetHome() {
        guard canContinueFromCurrentStep else { return }
        step = .addAdults
    }

    func continueFromAddAdults() {
        guard canContinueFromCurrentStep else { return }
        normalizeAdults()
        step = .addChildren
    }

    func continueFromAddChildren() {
        guard canContinueFromCurrentStep else { return }
        step = .review
    }

    func continueFromChildSetup() {
        guard canContinueFromCurrentStep else { return }
        step = .review
    }

    func goBack() {
        switch step {
        case .welcome:
            break
        case .createTribe, .joinTribe:
            step = .welcome
        case .setHome:
            step = (entryChoice == .join) ? .joinTribe : .createTribe
        case .addAdults:
            step = .setHome
        case .addChildren:
            step = .addAdults
        case .childSetup:
            step = .addChildren
        case .review:
            step = .childSetup
        }
    }

    func addAdult() {
        adults.append(
            Adult(
                id: UUID(),
                name: "",
                relationshipTag: nil,
                accessLevel: .standard,
                canDrive: false,
                avatarImageName: "",
                avatarSymbol: nil,
                avatarURL: nil,
                avatarSeed: UUID().uuidString
            )
        )
    }

    func addChild(
        id: UUID = UUID(),
        name: String = "",
        dateOfBirth: Date? = nil,
        avatarImageName: String = "",
        avatarURL: String? = nil,
        avatarId: String? = nil,
        avatarSymbol: AvatarSymbol? = nil
    ) {
        let newChild = OnboardingChildDraft(
            id: id,
            name: name,
            dateOfBirth: dateOfBirth,
            avatarImageName: avatarImageName,
            avatarId: avatarId,
            avatarSymbol: avatarSymbol,
            avatarURL: avatarURL
        )
        children.append(newChild)
        if selectedChildID == nil {
            selectedChildID = newChild.id
        }
    }

    func updateChild(_ child: OnboardingChildDraft) {
        guard let idx = children.firstIndex(where: { $0.id == child.id }) else { return }
        children[idx] = child
    }

    func setAdultAvatarURL(id: UUID, photoURL: String?) {
        guard let index = adults.firstIndex(where: { $0.id == id }) else { return }
        adults[index].avatarURL = photoURL
    }

    func setAdultAvatarSymbol(id: UUID, symbol: AvatarSymbol?) {
        guard let index = adults.firstIndex(where: { $0.id == id }) else { return }
        adults[index].avatarSymbol = symbol
        adults[index].avatarImageName = symbol?.rawValue ?? ""
    }

    func setChildAvatarURL(id: UUID, photoURL: String?) {
        guard let index = children.firstIndex(where: { $0.id == id }) else { return }
        children[index].avatarURL = photoURL
    }

    func setChildAvatarSymbol(id: UUID, symbol: AvatarSymbol?) {
        guard let index = children.firstIndex(where: { $0.id == id }) else { return }
        children[index].avatarSymbol = symbol
        children[index].avatarId = symbol?.rawValue
        children[index].avatarImageName = symbol?.rawValue ?? ""
    }

    @discardableResult
    func finishOnboarding(into store: TribeStore) -> Bool {
        guard canFinish else { return false }

        if store.tribe == nil {
            store.createTribe(name: tribeName.isEmpty ? "Joined Tribe" : tribeName, tribeCode: familyCode.nilIfEmpty)
        }

        let home = TribeLocation(
            name: homeLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Home" : homeLabel,
            address: homeAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            type: .home,
            tribeId: store.tribe?.id
        )
        store.addOrUpdateLocation(home, setAsHome: true)

        for adult in adults {
            let name = adult.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let cleanedAvatarURL = adult.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            let permissions = permissions(for: adult)
            let mappedRoles = roles(for: adult)
            let member = TribeMember(
                fullName: name,
                avatarURL: (cleanedAvatarURL?.isEmpty == false) ? cleanedAvatarURL : nil,
                avatarSeed: adult.avatarSeed,
                avatarImageName: adult.avatarImageName.nilIfEmpty,
                avatarSymbol: adult.avatarSymbol ?? AvatarSymbol.fromLegacyImageName(adult.avatarImageName.nilIfEmpty),
                role: .parent,
                permissions: permissions,
                memberType: .adult,
                relationship: adult.relationshipTag?.rawValue,
                roles: mappedRoles
            )
            store.addMember(member)
        }

        let driverIds = store.members
            .filter { $0.permissions.contains(.driver) }
            .map(\.id)
        let trackerIds = store.members
            .filter { $0.permissions.contains(.observer) || $0.permissions.contains(.admin) }
            .map(\.id)

        for child in children {
            guard !child.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            guard child.isComplete else { continue }
            let cleanedAvatarURL = child.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedAvatarId = child.avatarId?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedAvatarImageName = (resolvedAvatarId?.isEmpty == false) ? resolvedAvatarId : child.avatarImageName.nilIfEmpty
            let childMember = TribeMember(
                fullName: child.name,
                avatarURL: (cleanedAvatarURL?.isEmpty == false) ? cleanedAvatarURL : nil,
                avatarSeed: child.avatarSeed,
                avatarImageName: resolvedAvatarImageName,
                avatarSymbol: child.avatarSymbol ?? AvatarSymbol.fromLegacyImageName(resolvedAvatarImageName),
                memberType: .child,
                dateOfBirth: child.dateOfBirth,
                roles: [.child, .passenger]
            )
            store.addMember(childMember)

            var createdVenueLocationIds: [UUID] = []
            for venue in child.venues {
                let location = TribeLocation(
                    name: venue.label,
                    address: venue.place.formattedAddress,
                    type: venue.type == .school ? .school : .activity,
                    tribeId: store.tribe?.id,
                    childId: childMember.id,
                    linkedChildIds: [childMember.id]
                )
                store.addOrUpdateLocation(location)
                createdVenueLocationIds.append(location.id)

                let ruleIdSet = Set(venue.ruleIds)
                let rules = child.venueRules.filter { $0.venueId == venue.id && $0.isValid && (ruleIdSet.isEmpty || ruleIdSet.contains($0.id)) }
                for rule in rules {
                    let weekdays = Set(rule.weekdays.map(\.calendarWeekday))
                    let preferredDriver = driverIds.first
                    switch rule.tripMode {
                    case .roundTrip:
                        guard let drop = rule.dropOffTime, let pick = rule.pickupTime else { continue }
                        store.scheduleTemplates.append(
                            ScheduleTemplate(
                                title: "\(child.name) \(venue.label) Drop-off",
                                type: .dropoff,
                                venueId: location.id,
                                venueRuleId: rule.id,
                                originLocationId: store.tribe?.homeLocationId ?? location.id,
                                destinationLocationId: location.id,
                                childIds: [childMember.id],
                                preferredDriverId: preferredDriver,
                                weekdays: weekdays,
                                timeHour: drop.hour ?? 7,
                                timeMinute: drop.minute ?? 45
                            )
                        )
                        store.scheduleTemplates.append(
                            ScheduleTemplate(
                                title: "\(child.name) \(venue.label) Pickup",
                                type: .pickup,
                                venueId: location.id,
                                venueRuleId: rule.id,
                                originLocationId: location.id,
                                destinationLocationId: store.tribe?.homeLocationId ?? location.id,
                                childIds: [childMember.id],
                                preferredDriverId: preferredDriver,
                                weekdays: weekdays,
                                timeHour: pick.hour ?? 14,
                                timeMinute: pick.minute ?? 30
                            )
                        )
                        store.routines.append(
                            Routine(
                                childId: childMember.id,
                                weekdays: weekdays,
                                dropoffTime: drop,
                                pickupTime: pick
                            )
                        )
                    case .dropOffOnly:
                        guard let drop = rule.dropOffTime else { continue }
                        store.scheduleTemplates.append(
                            ScheduleTemplate(
                                title: "\(child.name) \(venue.label) Drop-off",
                                type: .dropoff,
                                venueId: location.id,
                                venueRuleId: rule.id,
                                originLocationId: store.tribe?.homeLocationId ?? location.id,
                                destinationLocationId: location.id,
                                childIds: [childMember.id],
                                preferredDriverId: preferredDriver,
                                weekdays: weekdays,
                                timeHour: drop.hour ?? 7,
                                timeMinute: drop.minute ?? 45
                            )
                        )
                    case .pickupOnly:
                        guard let pick = rule.pickupTime else { continue }
                        store.scheduleTemplates.append(
                            ScheduleTemplate(
                                title: "\(child.name) \(venue.label) Pickup",
                                type: .pickup,
                                venueId: location.id,
                                venueRuleId: rule.id,
                                originLocationId: location.id,
                                destinationLocationId: store.tribe?.homeLocationId ?? location.id,
                                childIds: [childMember.id],
                                preferredDriverId: preferredDriver,
                                weekdays: weekdays,
                                timeHour: pick.hour ?? 14,
                                timeMinute: pick.minute ?? 30
                            )
                        )
                    }
                }
            }

            if let primaryVenueLocationId = createdVenueLocationIds.first {
                store.childProfiles.append(
                    ChildProfile(
                        memberId: childMember.id,
                        primarySchoolLocationId: primaryVenueLocationId,
                        activityLocationIds: Array(createdVenueLocationIds.dropFirst()),
                        allowedDriverIds: driverIds,
                        trackerMemberIds: trackerIds
                    )
                )
            }
        }

        return true
    }

    private func permissions(for adult: Adult) -> Set<MemberPermission> {
        var result: Set<MemberPermission> = []
        switch adult.accessLevel {
        case .admin:
            result.insert(.admin)
            result.insert(.observer)
        case .standard:
            break
        case .observer:
            result.insert(.observer)
        }
        if adult.canDrive && adult.accessLevel != .observer {
            result.insert(.driver)
        }
        return result
    }

    private func roles(for adult: Adult) -> Set<Role> {
        var mapped: Set<Role> = []
        if adult.accessLevel == .admin { mapped.insert(.admin) }
        if adult.accessLevel == .observer { mapped.insert(.observer) }
        if adult.canDrive && adult.accessLevel != .observer { mapped.insert(.driver) }
        if let relationshipTag = adult.relationshipTag {
            switch relationshipTag {
            case .parent, .guardian:
                mapped.insert(.parent)
            case .helper, .relative:
                mapped.insert(.observer)
            }
        }
        return mapped
    }

    private func normalizeAdults() {
        guard !adults.isEmpty else { return }
        adults[0].accessLevel = .admin
        if adults[0].accessLevel == .observer {
            adults[0].canDrive = false
        }
        for index in adults.indices where adults[index].accessLevel == .observer {
            adults[index].canDrive = false
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
