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

@MainActor
final class TribeStore: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()

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

    var scheduleTemplates: [ScheduleTemplate] = [] {
        willSet { objectWillChange.send() }
    }

    var routines: [Routine] = [] {
        willSet { objectWillChange.send() }
    }

    var runInstances: [RunInstance] = [] {
        willSet { objectWillChange.send() }
    }

    var runEvents: [MobilityRunEvent] = [] {
        willSet { objectWillChange.send() }
    }

    private var snoozedSuggestionUntil: [UUID: Date] = [:]
    private var dismissedSuggestionIDs: Set<UUID> = []

    init(demoFlow: Bool = false) {
        if demoFlow {
            tribe = Tribe(name: "Mawere Tribe", tribeCode: Self.generateTribeCode())
            members = Self.seedMembers()
            seedMobilityDemoData()
        }
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

    func updateMember(_ member: TribeMember) {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[index] = member
        syncTribeMemberIds()
    }

    func deleteMember(id: UUID) {
        members.removeAll { $0.id == id }
        syncTribeMemberIds()
    }

    @discardableResult
    func createChildWithSchoolAndDefaultSchedules(
        childName: String,
        avatarImageName: String?,
        avatarSymbol: AvatarSymbol? = nil,
        avatarURL: String? = nil,
        avatarSeed: String? = nil,
        schoolName: String,
        schoolAddress: String,
        dropoffTime: DateComponents,
        pickupTime: DateComponents,
        weekdays: Set<Int>,
        allowedDriverIds: [UUID],
        trackerMemberIds: [UUID]
    ) -> ChildProfile {
        let newChild = TribeMember(
            fullName: childName.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarURL: avatarURL,
            avatarSeed: avatarSeed,
            avatarImageName: avatarImageName,
            avatarSymbol: avatarSymbol ?? AvatarSymbol.fromLegacyImageName(avatarImageName),
            memberType: .child,
            roles: [.child, .passenger]
        )
        addMember(newChild)

        let school = TribeLocation(
            name: schoolName.trimmingCharacters(in: .whitespacesAndNewlines),
            address: schoolAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            type: .school,
            tribeId: tribe?.id,
            childId: newChild.id,
            linkedChildIds: [newChild.id]
        )
        addOrUpdateLocation(school)

        let homeId = resolveHomeLocationId()
        let preferredDriver = allowedDriverIds.first

        let dropoff = ScheduleTemplate(
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

        let pickup = ScheduleTemplate(
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
    func createRunInstanceFromSuggestion(_ suggestion: RunSuggestion, now: Date) -> RunInstance {
        let run = RunInstance(
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
                member.roles.contains(where: { $0.rawValue.lowercased().contains(query) })
            }
            .sorted { $0.fullName < $1.fullName }
    }

    static func generateTribeCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let suffix = String((0..<4).map { _ in characters.randomElement() ?? "X" })
        return "TRIBE-\(suffix)"
    }

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
                roles: [.child, .passenger, .observer],
                isLocationSharingEnabled: true,
                isOnline: false
            ),
            TribeMember(
                fullName: "Tawana",
                memberType: .child,
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -8, to: Date()),
                roles: [.child, .passenger, .observer],
                isLocationSharingEnabled: true,
                isOnline: false
            )
        ]
    }

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

    private func suggestedStartDate(for template: ScheduleTemplate, on reference: Date) -> Date {
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
            ScheduleTemplate(
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
            ScheduleTemplate(
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

    private func syncTribeMemberIds() {
        tribe?.memberIds = members.map(\.id)
    }

    private func childTemplates(for childId: UUID) -> [ScheduleTemplate] {
        scheduleTemplates.filter { $0.childIds.contains(childId) }
    }

    private func inferredVenueLocationId(for template: ScheduleTemplate) -> UUID? {
        if let venueId = template.venueId {
            return venueId
        }
        // Drop-off templates point to venue as destination; pickups point to venue as origin.
        return template.type == .dropoff ? template.destinationLocationId : template.originLocationId
    }

    private func nextOccurrenceDate(
        for template: ScheduleTemplate,
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
}
