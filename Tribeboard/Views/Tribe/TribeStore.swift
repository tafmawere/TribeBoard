import Combine
import Foundation

enum ChildConfigurationLevel {
    case notConfigured
    case partial
    case configured
}

struct ChildConfigurationSummary {
    var venueCount: Int
    var ruleCount: Int
    var level: ChildConfigurationLevel

    var statusText: String {
        if venueCount == 0 {
            return "No venues configured"
        }
        if ruleCount == 0 {
            return "\(venueCount) venue\(venueCount == 1 ? "" : "s") • No schedule rules"
        }
        return "\(venueCount) venue\(venueCount == 1 ? "" : "s") • \(ruleCount) rule\(ruleCount == 1 ? "" : "s")"
    }
}

struct FamilySummary: Equatable {
    var totalMembers: Int
    var totalChildren: Int
    var totalDrivers: Int
    var totalObservers: Int

    static let empty = FamilySummary(
        totalMembers: 0,
        totalChildren: 0,
        totalDrivers: 0,
        totalObservers: 0
    )

    static func calculate(
        activeMemberships: [BackendHouseholdMembership],
        householdPeople: [BackendHouseholdPerson],
        children: [BackendChild]
    ) -> FamilySummary {
        var driverIds = Set<UUID>()
        var observerIds = Set<UUID>()

        for membership in activeMemberships {
            if membershipCountsAsDriver(membership) {
                driverIds.insert(membership.id)
            }
            if membership.normalizedAccessRole == .observer {
                observerIds.insert(membership.id)
            }
        }

        for person in householdPeople {
            if personCountsAsDriver(person) {
                driverIds.insert(person.id)
            }
            if personCountsAsObserver(person) {
                observerIds.insert(person.id)
            }
        }

        return FamilySummary(
            totalMembers: activeMemberships.count + householdPeople.count,
            totalChildren: children.count,
            totalDrivers: driverIds.count,
            totalObservers: observerIds.count
        )
    }

    private static func membershipCountsAsDriver(_ membership: BackendHouseholdMembership) -> Bool {
        if membership.normalizedAccessRole == .driver { return true }
        return [
            membership.role,
            membership.accessRole,
            membership.familyRole,
            membership.relationshipLabel
        ]
        .compactMap { $0?.lowercased() }
        .contains { $0.contains("driver") }
    }

    private static func personCountsAsDriver(_ person: BackendHouseholdPerson) -> Bool {
        if person.isDriver { return true }
        return [
            person.role,
            person.relationship,
            person.name
        ]
        .compactMap { $0?.lowercased() }
        .contains { $0.contains("driver") }
    }

    private static func personCountsAsObserver(_ person: BackendHouseholdPerson) -> Bool {
        let values = [
            person.role,
            person.relationship
        ]
        .compactMap { $0?.lowercased() }
        return values.contains { value in
            value.contains("observer") ||
            value.contains("helper") ||
            value.contains("relative") ||
            value.contains("support")
        }
    }
}

@MainActor
final class FamilyStore: ObservableObject {
    @Published private(set) var summary: FamilySummary = .empty

    func updateSummary(
        activeMemberships: [BackendHouseholdMembership],
        householdPeople: [BackendHouseholdPerson],
        children: [BackendChild]
    ) {
        summary = FamilySummary.calculate(
            activeMemberships: activeMemberships,
            householdPeople: householdPeople,
            children: children
        )
    }

    func clearSummary() {
        summary = .empty
    }
}

@MainActor
final class TribeStore: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()
    let familyStore = FamilyStore()

    var tribe: Tribe? {
        willSet { objectWillChange.send() }
    }

    var members: [TribeMember] = [] {
        willSet { objectWillChange.send() }
    }

    var childProfiles: [ChildProfile] = [] {
        willSet { objectWillChange.send() }
    }

    var locations: [TribeLocation] = [] {
        willSet { objectWillChange.send() }
    }

    var scheduleTemplates: [LegacyScheduleTemplate] = [] {
        willSet { objectWillChange.send() }
    }

    var routines: [Routine] = [] {
        willSet { objectWillChange.send() }
    }

    var runInstances: [LegacyRunInstance] = [] {
        willSet { objectWillChange.send() }
    }

    var runEvents: [MobilityRunEvent] = [] {
        willSet { objectWillChange.send() }
    }

    var familySummary: FamilySummary {
        familyStore.summary
    }

    private var snoozedSuggestionUntil: [UUID: Date] = [:]
    private var dismissedSuggestionIDs: Set<UUID> = []

    init(demoFlow: Bool = false) {
#if DEBUG
        if demoFlow && AppConfig.isDemoFlowEnabled {
            tribe = Tribe(name: "Mawere Tribe", tribeCode: Self.generateTribeCode())
            members = Self.seedMembers()
            seedMobilityDemoData()
        }
#endif
    }

    func createTribe(name: String, tribeCode: String? = nil) {
        let code = tribeCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCode: String = (code?.isEmpty == false) ? code! : Self.generateTribeCode()
        tribe = Tribe(name: name.trimmingCharacters(in: .whitespacesAndNewlines), tribeCode: resolvedCode)
    }

    func addMember(_ member: TribeMember) {
        members.append(member)
        syncTribeMemberIds()
    }

    func upsertMember(_ member: TribeMember) {
        if let index = members.firstIndex(where: { $0.id == member.id }) {
            members[index] = member
        } else {
            members.append(member)
        }
        syncTribeMemberIds()
    }

    func updateMember(_ member: TribeMember) {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[index] = member
        syncTribeMemberIds()
    }

    func deleteMember(id: UUID) {
        members.removeAll { $0.id == id }
        syncTribeMemberIds()
    }

    func updateFamilySummary(
        activeMemberships: [BackendHouseholdMembership],
        householdPeople: [BackendHouseholdPerson],
        children: [BackendChild]
    ) {
        objectWillChange.send()
        familyStore.updateSummary(
            activeMemberships: activeMemberships,
            householdPeople: householdPeople,
            children: children
        )
    }

    func clearFamilySummary() {
        objectWillChange.send()
        familyStore.clearSummary()
    }

    func upsertChildrenFromBackend(_ backendChildren: [TribeMember]) {
        let normalized = backendChildren.filter { $0.memberType == .child }
        guard !normalized.isEmpty else { return }
        for child in normalized {
            if let index = members.firstIndex(where: { $0.id == child.id }) {
                members[index] = child
            } else {
                members.append(child)
            }
        }
        syncTribeMemberIds()
    }

    func replaceChildActivities(childId: UUID, activities: [ChildActivity]) {
        guard let index = members.firstIndex(where: { $0.id == childId && $0.memberType == .child }) else { return }
        members[index].activities = activities
    }

    func upsertChildActivity(childId: UUID, activity: ChildActivity) {
        guard let index = members.firstIndex(where: { $0.id == childId && $0.memberType == .child }) else { return }
        if let existing = members[index].activities.firstIndex(where: { $0.id == activity.id }) {
            members[index].activities[existing] = activity
        } else {
            members[index].activities.append(activity)
        }
    }

    func removeChildActivity(childId: UUID, activityId: UUID) {
        guard let index = members.firstIndex(where: { $0.id == childId && $0.memberType == .child }) else { return }
        members[index].activities.removeAll { $0.id == activityId }
    }

    @discardableResult
    func createChildWithSchoolAndDefaultSchedules(
        childName: String,
        avatarImageName: String?,
        avatarSymbol: AvatarSymbol? = nil,
        avatarURL: String? = nil,
        avatarSeed: String? = nil,
        displayName: String? = nil,
        dateOfBirth: Date? = nil,
        schoolName: String? = nil,
        schoolAddress: String? = nil,
        gradeOrClass: String? = nil,
        schoolLatitude: Double? = nil,
        schoolLongitude: Double? = nil,
        schoolStartTime: DateComponents? = nil,
        schoolEndTime: DateComponents? = nil,
        schoolDays: Set<Weekday>? = nil,
        dropoffTime: DateComponents,
        pickupTime: DateComponents,
        weekdays: Set<Int>,
        allowedDriverIds: [UUID],
        trackerMemberIds: [UUID],
        childId: UUID? = nil
    ) -> ChildProfile? {
        let newChild = TribeMember(
            id: childId ?? UUID(),
            fullName: childName.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarURL: avatarURL,
            avatarSeed: avatarSeed,
            avatarImageName: avatarImageName,
            avatarSymbol: avatarSymbol ?? AvatarSymbol.fromLegacyImageName(avatarImageName),
            memberType: .child,
            dateOfBirth: dateOfBirth,
            displayName: displayName,
            schoolName: schoolName,
            schoolAddress: schoolAddress,
            gradeOrClass: gradeOrClass,
            schoolStartTime: schoolStartTime,
            schoolEndTime: schoolEndTime,
            schoolDays: schoolDays,
            roles: [.child, .passenger]
        )
        addMember(newChild)

        let normalizedSchoolName = schoolName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedSchoolAddress = schoolAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalizedSchoolName.isEmpty, !normalizedSchoolAddress.isEmpty else {
            return nil
        }

        let school = TribeLocation(
            name: normalizedSchoolName,
            address: normalizedSchoolAddress,
            type: .school,
            tribeId: tribe?.id,
            childId: newChild.id,
            linkedChildIds: [newChild.id],
            notes: schoolCoordinateNote(latitude: schoolLatitude, longitude: schoolLongitude)
        )
        addOrUpdateLocation(school)

        let homeId = resolveHomeLocationId()
        let preferredDriver = allowedDriverIds.first

        let dropoff = LegacyScheduleTemplate(
            title: "\(childName) School Drop-off",
            type: .dropoff,
            originLocationId: homeId,
            destinationLocationId: school.id,
            childIds: [newChild.id],
            preferredDriverId: preferredDriver,
            weekdays: weekdays,
            timeHour: dropoffTime.hour ?? 7,
            timeMinute: dropoffTime.minute ?? 30
        )

        let pickup = LegacyScheduleTemplate(
            title: "\(childName) School Pickup",
            type: .pickup,
            originLocationId: school.id,
            destinationLocationId: homeId,
            childIds: [newChild.id],
            preferredDriverId: preferredDriver,
            weekdays: weekdays,
            timeHour: pickupTime.hour ?? 14,
            timeMinute: pickupTime.minute ?? 30
        )

        scheduleTemplates.append(dropoff)
        scheduleTemplates.append(pickup)

        let profile = ChildProfile(
            memberId: newChild.id,
            primarySchoolLocationId: school.id,
            allowedDriverIds: allowedDriverIds,
            trackerMemberIds: trackerMemberIds
        )
        childProfiles.append(profile)
        routines.append(
            Routine(
                childId: newChild.id,
                weekdays: weekdays,
                dropoffTime: dropoffTime,
                pickupTime: pickupTime
            )
        )
        return profile
    }

    func addOrUpdateLocation(_ location: TribeLocation, setAsHome: Bool = false) {
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index] = location
        } else {
            locations.append(location)
        }

        if setAsHome || location.type == .home {
            tribe?.homeLocationId = location.id
        }
    }

    func generateSuggestedRuns(now: Date) -> [RunSuggestion] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        return scheduleTemplates
            .filter { template in
                template.isEnabled &&
                template.weekdays.contains(weekday) &&
                !dismissedSuggestionIDs.contains(template.id)
            }
            .compactMap { template in
                let proposedStart = suggestedStartDate(for: template, on: now)
                let minutesDelta = proposedStart.timeIntervalSince(now) / 60.0
                guard minutesDelta >= -30, minutesDelta <= 60 else { return nil }
                guard !isTemplateAlreadyCreatedToday(templateId: template.id, referenceDate: now) else { return nil }

                if let snoozeUntil = snoozedSuggestionUntil[template.id], snoozeUntil > now {
                    return nil
                }

                let origin = locations.first(where: { $0.id == template.originLocationId })?.name ?? "Origin"
                let destination = locations.first(where: { $0.id == template.destinationLocationId })?.name ?? "Destination"
                let childMembers = members.filter { template.childIds.contains($0.id) }
                let driver = members.first(where: { $0.id == template.preferredDriverId })

                return RunSuggestion(
                    id: template.id,
                    scheduleTemplateId: template.id,
                    title: template.title,
                    proposedStart: proposedStart,
                    originName: origin,
                    destinationName: destination,
                    childIds: template.childIds,
                    childNames: childMembers.map(\.fullName),
                    childAvatarImageNames: childMembers.map(\.avatarImageName),
                    driverMemberId: template.preferredDriverId,
                    driverName: driver?.fullName,
                    sourceType: template.type
                )
            }
            .sorted { $0.proposedStart < $1.proposedStart }
    }

    @discardableResult
    func createRunInstanceFromSuggestion(_ suggestion: RunSuggestion, now: Date) -> LegacyRunInstance {
        let run = LegacyRunInstance(
            scheduleTemplateId: suggestion.scheduleTemplateId,
            title: suggestion.title,
            plannedStart: suggestion.proposedStart,
            originLocationId: scheduleTemplates.first(where: { $0.id == suggestion.scheduleTemplateId })?.originLocationId ?? resolveHomeLocationId(),
            destinationLocationId: scheduleTemplates.first(where: { $0.id == suggestion.scheduleTemplateId })?.destinationLocationId ?? resolveHomeLocationId(),
            childIds: suggestion.childIds,
            driverMemberId: suggestion.driverMemberId,
            status: now >= suggestion.proposedStart ? .active : .scheduled,
            progress: .toPickup
        )
        runInstances.append(run)
        return run
    }

    func snoozeSuggestion(_ suggestion: RunSuggestion, minutes: Int = 10, now: Date = Date()) {
        snoozedSuggestionUntil[suggestion.scheduleTemplateId] = now.addingTimeInterval(TimeInterval(minutes * 60))
    }

    func dismissSuggestion(_ suggestion: RunSuggestion) {
        dismissedSuggestionIDs.insert(suggestion.scheduleTemplateId)
    }

    func childConfigurationSummary(for childId: UUID) -> ChildConfigurationSummary {
        let venues = venueCount(for: childId)
        let rules = ruleCount(for: childId)
        let level: ChildConfigurationLevel
        if venues == 0 {
            level = .notConfigured
        } else if rules == 0 {
            level = .partial
        } else {
            level = .configured
        }
        return ChildConfigurationSummary(venueCount: venues, ruleCount: rules, level: level)
    }

    func venueCount(for childId: UUID) -> Int {
        let linkedLocations = locations.filter {
            $0.type != .home && ($0.childId == childId || $0.linkedChildIds.contains(childId))
        }
        let linkedIDs = Set(linkedLocations.map(\.id))
        if !linkedIDs.isEmpty {
            return linkedIDs.count
        }

        let templateVenueIDs = Set(
            childTemplates(for: childId)
                .compactMap { inferredVenueLocationId(for: $0) }
        )
        return templateVenueIDs.count
    }

    func schoolName(for childId: UUID) -> String? {
        if let child = members.first(where: { $0.id == childId }),
           let direct = child.schoolName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !direct.isEmpty {
            return direct
        }

        if let profile = childProfiles.first(where: { $0.memberId == childId }),
           let location = locations.first(where: { $0.id == profile.primarySchoolLocationId }) {
            let trimmed = location.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let linked = locations.first(where: {
            $0.type == .school && ($0.childId == childId || $0.linkedChildIds.contains(childId))
        }) {
            let trimmed = linked.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    func childrenMissingSchoolCount() -> Int {
        members
            .filter { $0.memberType == .child }
            .filter { schoolName(for: $0.id) == nil }
            .count
    }

    func childrenMissingSchoolRoutineCount() -> Int {
        members
            .filter { $0.memberType == .child }
            .filter { $0.hasSchoolConfigured && !$0.hasSchoolRoutineConfigured }
            .count
    }

    func ruleCount(for childId: UUID) -> Int {
        let templates = childTemplates(for: childId)
        let ruleIDs = Set(templates.compactMap(\.venueRuleId))
        if !ruleIDs.isEmpty {
            return ruleIDs.count
        }
        guard !templates.isEmpty else { return 0 }

        // Legacy fallback when venueRuleId isn't available.
        var grouped: [String: (drop: Set<String>, pick: Set<String>)] = [:]
        for template in templates {
            let venueToken = inferredVenueLocationId(for: template)?.uuidString ?? "unknown"
            let weekdays = template.weekdays.sorted().map(String.init).joined(separator: ",")
            let groupKey = "\(venueToken)|\(weekdays)"
            let timeToken = "\(template.timeHour):\(template.timeMinute)"
            var bucket = grouped[groupKey] ?? (drop: [], pick: [])
            if template.type == .dropoff {
                bucket.drop.insert(timeToken)
            } else {
                bucket.pick.insert(timeToken)
            }
            grouped[groupKey] = bucket
        }

        return grouped.values.reduce(0) { partial, bucket in
            partial + max(bucket.drop.count, bucket.pick.count)
        }
    }

    func nextUpcomingRun(for childId: UUID, now: Date = Date(), lookaheadDays: Int = 14) -> RunSuggestion? {
        let calendar = Calendar.current
        let templates = childTemplates(for: childId).filter(\.isEnabled)
        guard !templates.isEmpty else { return nil }

        let childMembers = members.filter { $0.id == childId }
        let childNames = childMembers.map(\.fullName)
        let childAvatarImageNames = childMembers.map(\.avatarImageName)

        var best: RunSuggestion?

        for template in templates {
            guard let proposedStart = nextOccurrenceDate(for: template, after: now, calendar: calendar, lookaheadDays: lookaheadDays) else {
                continue
            }
            let origin = locations.first(where: { $0.id == template.originLocationId })?.name ?? "Origin"
            let destination = locations.first(where: { $0.id == template.destinationLocationId })?.name ?? "Destination"
            let driver = members.first(where: { $0.id == template.preferredDriverId })

            let suggestion = RunSuggestion(
                id: template.id,
                scheduleTemplateId: template.id,
                title: template.title,
                proposedStart: proposedStart,
                originName: origin,
                destinationName: destination,
                childIds: [childId],
                childNames: childNames,
                childAvatarImageNames: childAvatarImageNames,
                driverMemberId: template.preferredDriverId,
                driverName: driver?.fullName,
                sourceType: template.type
            )

            if let current = best {
                if suggestion.proposedStart < current.proposedStart {
                    best = suggestion
                }
            } else {
                best = suggestion
            }
        }

        return best
    }

    func adults(matching searchText: String = "") -> [TribeMember] {
        filteredMembers(matching: searchText).filter { $0.memberType == .adult }
    }

    func children(matching searchText: String = "") -> [TribeMember] {
        filteredMembers(matching: searchText).filter { $0.memberType == .child }
    }

    private func filteredMembers(matching searchText: String) -> [TribeMember] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return members.sorted { $0.fullName < $1.fullName }
        }

        return members
            .filter { member in
                member.fullName.lowercased().contains(query) ||
                member.preferredDisplayName.lowercased().contains(query) ||
                member.roles.contains(where: { $0.rawValue.lowercased().contains(query) })
            }
            .sorted { $0.fullName < $1.fullName }
    }

    static func generateTribeCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let suffix = String((0..<4).map { _ in characters.randomElement() ?? "X" })
        return "TRIBE-\(suffix)"
    }

#if DEBUG
    private static func seedMembers() -> [TribeMember] {
        [
            TribeMember(
                fullName: "Rue",
                memberType: .adult,
                relationship: "Mom",
                phone: "+263 77 100 0001",
                roles: [.admin, .observer, .parent],
                isLocationSharingEnabled: true,
                isOnline: true
            ),
            TribeMember(
                fullName: "Tafadzwa",
                memberType: .adult,
                relationship: "Dad",
                phone: "+263 77 100 0002",
                roles: [.admin, .driver, .parent],
                isLocationSharingEnabled: true,
                isOnline: true
            ),
            TribeMember(
                fullName: "TJ",
                memberType: .child,
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -10, to: Date()),
                schoolName: "Lincoln Elementary",
                roles: [.child, .passenger, .observer],
                isLocationSharingEnabled: true,
                isOnline: false
            ),
            TribeMember(
                fullName: "Tawana",
                memberType: .child,
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -8, to: Date()),
                schoolName: "Lincoln Elementary",
                roles: [.child, .passenger, .observer],
                isLocationSharingEnabled: true,
                isOnline: false
            )
        ]
    }
#endif

    private func resolveHomeLocationId() -> UUID {
        if let homeId = tribe?.homeLocationId {
            return homeId
        }
        if let existingHome = locations.first(where: { $0.type == .home }) {
            tribe?.homeLocationId = existingHome.id
            return existingHome.id
        }
        let fallback = TribeLocation(name: "Home", address: "123 Maple St", type: .home)
        locations.append(fallback)
        tribe?.homeLocationId = fallback.id
        return fallback.id
    }

    private func suggestedStartDate(for template: LegacyScheduleTemplate, on reference: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reference)
        components.hour = template.timeHour
        components.minute = template.timeMinute
        components.second = 0
        return Calendar.current.date(from: components) ?? reference
    }

    private func isTemplateAlreadyCreatedToday(templateId: UUID, referenceDate: Date) -> Bool {
        let calendar = Calendar.current
        return runInstances.contains {
            $0.scheduleTemplateId == templateId &&
            calendar.isDate($0.plannedStart, inSameDayAs: referenceDate)
        }
    }

#if DEBUG
    private func seedMobilityDemoData() {
        let home = TribeLocation(name: "Home", address: "123 Maple St", type: .home)
        let school = TribeLocation(name: "Lincoln Elementary", address: "456 School Ave", type: .school)
        locations = [home, school]
        tribe?.homeLocationId = home.id

        guard let child = members.first(where: { $0.memberType == .child }) else { return }
        let drivers = members.filter { $0.roles.contains(.driver) || $0.roles.contains(.admin) }.map(\.id)
        let trackers = members.filter { $0.roles.contains(.observer) || $0.roles.contains(.admin) }.map(\.id)

        childProfiles = [
            ChildProfile(
                memberId: child.id,
                primarySchoolLocationId: school.id,
                allowedDriverIds: drivers,
                trackerMemberIds: trackers
            )
        ]

        routines = [
            Routine(
                childId: child.id,
                weekdays: [2, 3, 4, 5, 6],
                dropoffTime: DateComponents(hour: 7, minute: 45),
                pickupTime: DateComponents(hour: 14, minute: 30)
            )
        ]

        scheduleTemplates = [
            LegacyScheduleTemplate(
                title: "\(child.fullName) School Drop-off",
                type: .dropoff,
                originLocationId: home.id,
                destinationLocationId: school.id,
                childIds: [child.id],
                preferredDriverId: drivers.first,
                weekdays: [2, 3, 4, 5, 6],
                timeHour: 7,
                timeMinute: 45
            ),
            LegacyScheduleTemplate(
                title: "\(child.fullName) School Pickup",
                type: .pickup,
                originLocationId: school.id,
                destinationLocationId: home.id,
                childIds: [child.id],
                preferredDriverId: drivers.first,
                weekdays: [2, 3, 4, 5, 6],
                timeHour: 14,
                timeMinute: 30
            )
        ]

        syncTribeMemberIds()
    }
#endif

    private func syncTribeMemberIds() {
        tribe?.memberIds = members.map(\.id)
    }

    private func childTemplates(for childId: UUID) -> [LegacyScheduleTemplate] {
        scheduleTemplates.filter { $0.childIds.contains(childId) }
    }

    private func inferredVenueLocationId(for template: LegacyScheduleTemplate) -> UUID? {
        if let venueId = template.venueId {
            return venueId
        }
        // Drop-off templates point to venue as destination; pickups point to venue as origin.
        return template.type == .dropoff ? template.destinationLocationId : template.originLocationId
    }

    private func nextOccurrenceDate(
        for template: LegacyScheduleTemplate,
        after reference: Date,
        calendar: Calendar,
        lookaheadDays: Int
    ) -> Date? {
        let startOfReference = calendar.startOfDay(for: reference)
        for dayOffset in 0...lookaheadDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfReference) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            guard template.weekdays.contains(weekday) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = template.timeHour
            components.minute = template.timeMinute
            components.second = 0
            guard let candidate = calendar.date(from: components), candidate >= reference else { continue }
            return candidate
        }
        return nil
    }

    private func schoolCoordinateNote(latitude: Double?, longitude: Double?) -> String? {
        guard let latitude, let longitude else { return nil }
        return "lat=\(latitude),lon=\(longitude)"
    }
}
