import Foundation
import Combine

@MainActor
final class BackendChildrenContext: ObservableObject {
    @Published private(set) var children: [BackendChild] = []
    @Published private(set) var activities: [BackendChildActivity] = []
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?

    private let service: ChildBackendService
    private let authService: AuthService
    private let householdContext: BackendHouseholdContext
    private let store: TribeStore
    private weak var householdLocationsContext: BackendHouseholdLocationsContext?
    private var currentSession: AuthUserSession?
    private var isRealtimeRefreshInFlight = false
    private var hasPendingRealtimeRefresh = false
    private var realtimeDebounceTask: Task<Void, Never>?

    init(
        service: ChildBackendService? = nil,
        authService: AuthService? = nil,
        householdContext: BackendHouseholdContext,
        store: TribeStore,
        householdLocationsContext: BackendHouseholdLocationsContext? = nil
    ) {
        self.service = service ?? SupabaseChildBackendService()
        self.authService = authService ?? SupabaseAuthService()
        self.householdContext = householdContext
        self.store = store
        self.householdLocationsContext = householdLocationsContext
    }

    func refreshForActiveHousehold() async {
        guard householdContext.hasActiveMembership,
              let householdId = householdContext.activeHouseholdId else {
            children = []
            activities = []
            lastError = nil
            return
        }
        await refreshChildren(householdId: householdId)
    }

    func handleRealtimeEvent(_ event: RealtimeChangeEvent) async {
        guard let activeHouseholdId = householdContext.activeHouseholdId else { return }
        guard event.householdId == nil || event.householdId == activeHouseholdId else { return }
        guard event.entityType == .child || event.entityType == .childActivity else { return }

        realtimeDebounceTask?.cancel()
        realtimeDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            await self?.runSafeRealtimeRefresh(for: activeHouseholdId)
        }
    }

    func refreshChildren(householdId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return
            }

            let previousBackendChildIds = Set(children.map(\.id))
            let backendChildren = try await service.fetchChildren(householdId: householdId, session: session)
#if DEBUG
            print(
                "[BackendChildrenContext] fetch returned rows=\(backendChildren.count), " +
                "activeHouseholdId=\(householdId.uuidString)"
            )
#endif
            let newBackendChildIds = Set(backendChildren.map(\.id))
            await MainActor.run {
                children = backendChildren
            }
            store.upsertChildrenFromBackend(backendChildren.map(mapToTribeMember))
            let removedChildIds = previousBackendChildIds.subtracting(newBackendChildIds)
            for removedId in removedChildIds {
                store.deleteMember(id: removedId)
            }

            var allActivities: [BackendChildActivity] = []
            for child in backendChildren {
                let childActivities = try await service.fetchChildActivities(childId: child.id, session: session)
                allActivities.append(contentsOf: childActivities)
                store.replaceChildActivities(
                    childId: child.id,
                    activities: childActivities.map(mapToChildActivity)
                )
            }
            await MainActor.run {
                activities = allActivities
                lastError = nil
            }
#if DEBUG
            print(
                "[BackendChildrenContext] published children_count=\(children.count), " +
                "activeHouseholdId=\(householdId.uuidString)"
            )
#endif
        } catch {
            lastError = error.localizedDescription
        }
    }

    func createChildLocallyThenSync(_ member: TribeMember) async {
        _ = await createChild(member)
    }

    @discardableResult
    func createChild(_ member: TribeMember) async -> Bool {
        guard member.memberType == .child else { return false }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let householdId = householdContext.activeHouseholdId else {
                lastError = "Unable to create child. No active backend household."
                return false
            }
            guard let session = try await ensuredSession() else {
                lastError = "Unable to create child. No active auth session."
                return false
            }

            let created = try await service.createChild(
                mapToBackendChild(member: member, householdId: householdId),
                session: session
            )

            for activity in member.activities {
                let createdActivity = try await service.createChildActivity(
                    mapToBackendActivity(activity, childId: created.id, householdId: householdId),
                    session: session
                )
                activities.removeAll { $0.id == createdActivity.id }
                activities.append(createdActivity)
            }
            store.upsertMember(mapToTribeMember(created))
            await refreshChildren(householdId: householdId)
            lastError = nil
            return true
        } catch {
            lastError = "Backend save failed. Child was not created on the server. \(error.localizedDescription)"
            return false
        }
    }

    func updateChildSchoolLocation(_ child: BackendChild) async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return
            }
            _ = try await service.updateChild(child, session: session)
            if let householdId = householdContext.activeHouseholdId {
                await refreshChildren(householdId: householdId)
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateChildLocallyThenSync(_ member: TribeMember) async {
        store.upsertMember(member)
        guard member.memberType == .child else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let householdId = householdContext.activeHouseholdId else {
                lastError = "No active backend household."
                return
            }
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return
            }
            _ = try await service.updateChild(
                mapToBackendChild(member: member, householdId: householdId),
                session: session
            )
            await refreshChildren(householdId: householdId)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteChildLocallyThenSync(id: UUID) async {
        store.deleteMember(id: id)
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return
            }
            try await service.deleteChild(id: id, session: session)
            children.removeAll { $0.id == id }
            activities.removeAll { $0.childId == id }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshActivities(childId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return
            }
            let fetched = try await service.fetchChildActivities(childId: childId, session: session)
            activities.removeAll { $0.childId == childId }
            activities.append(contentsOf: fetched)
            store.replaceChildActivities(childId: childId, activities: fetched.map(mapToChildActivity))
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func upsertActivityLocallyThenSync(childId: UUID, activity: ChildActivity) async {
        store.upsertChildActivity(childId: childId, activity: activity)
        isLoading = true
        defer { isLoading = false }
        do {
            guard let householdId = householdContext.activeHouseholdId else {
                lastError = "No active backend household."
                return
            }
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return
            }

            let existing = activities.first(where: { $0.id == activity.id })
            if existing != nil {
                let updated = try await service.updateChildActivity(
                    mapToBackendActivity(activity, childId: childId, householdId: householdId),
                    session: session
                )
                activities.removeAll { $0.id == updated.id }
                activities.append(updated)
            } else {
                let created = try await service.createChildActivity(
                    mapToBackendActivity(activity, childId: childId, householdId: householdId),
                    session: session
                )
                activities.removeAll { $0.id == created.id }
                activities.append(created)
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteActivityLocallyThenSync(childId: UUID, activityId: UUID) async {
        store.removeChildActivity(childId: childId, activityId: activityId)
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return
            }
            try await service.deleteChildActivity(id: activityId, session: session)
            activities.removeAll { $0.id == activityId }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func mapToTribeMember(_ child: BackendChild) -> TribeMember {
        let existing = store.members.first(where: { $0.id == child.id && $0.memberType == .child })
        let existingRoles = existing?.roles ?? [.child, .passenger]
        let normalizedRoles: Set<Role> = {
            var roles: Set<Role> = [.child]
            if existingRoles.contains(.passenger) {
                roles.insert(.passenger)
            }
            return roles
        }()
        return TribeMember(
            id: child.id,
            fullName: child.legalName,
            avatarType: AvatarType(rawValue: child.avatarType ?? AvatarType.preset.rawValue),
            avatarKey: child.avatarKey ?? AvatarPresetCatalog.defaultChildKey,
            avatarURL: child.avatarURL,
            memberType: .child,
            dateOfBirth: parseDateOnly(child.dateOfBirth),
            displayName: child.displayName,
            schoolName: child.schoolName,
            schoolAddress: existing?.schoolAddress,
            gradeOrClass: child.gradeOrClass,
            schoolStartTime: existing?.schoolStartTime,
            schoolEndTime: existing?.schoolEndTime,
            schoolDays: existing?.schoolDays,
            roles: normalizedRoles,
            isLocationSharingEnabled: true,
            isOnline: false
        )
    }

    private func mapToBackendChild(member: TribeMember, householdId: UUID) -> BackendChild {
        let existingChild = children.first(where: { $0.id == member.id })
        return BackendChild(
            id: member.id,
            householdId: householdId,
            legalName: member.fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: member.displayName,
            dateOfBirth: formatDateOnly(member.dateOfBirth),
            schoolName: member.schoolName,
            schoolLocationId: existingChild?.schoolLocationId,
            gradeOrClass: member.gradeOrClass,
            avatarType: member.avatarType?.rawValue ?? AvatarType.preset.rawValue,
            avatarKey: member.avatarKey ?? AvatarPresetCatalog.defaultChildKey,
            avatarURL: member.avatarURL,
            avatarUpdatedAt: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func mapToChildActivity(_ activity: BackendChildActivity) -> ChildActivity {
        ChildActivity(
            id: activity.id,
            name: activity.name,
            type: activity.type == "schoolBased" ? .schoolBased : .external,
            locationName: activity.locationName,
            days: Set(activity.days.compactMap(Weekday.init(rawValue:))),
            startTime: parseTime(activity.startTime),
            endTime: parseTime(activity.endTime)
        )
    }

    private func mapToBackendActivity(_ activity: ChildActivity, childId: UUID, householdId: UUID) -> BackendChildActivity {
        let trimmedLocationName = activity.locationName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let locationName = (trimmedLocationName?.isEmpty == false) ? trimmedLocationName : nil
        let resolvedLocationId = locationName.flatMap { name in
            SupabaseHouseholdLocationBackendService().findLocationByNameOrLabel(
                name,
                in: householdLocationsContext?.locations ?? [],
                preferredType: .activity
            )?.id
        }
        return BackendChildActivity(
            id: activity.id,
            childId: childId,
            householdId: householdId,
            name: activity.name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: activity.type.rawValue,
            locationName: locationName,
            locationId: resolvedLocationId,
            days: activity.days.map(\.rawValue).sorted(),
            startTime: formatTime(activity.startTime),
            endTime: formatTime(activity.endTime),
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func formatDateOnly(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func parseDateOnly(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func formatTime(_ components: DateComponents?) -> String? {
        guard let components,
              let hour = components.hour,
              let minute = components.minute else { return nil }
        return String(format: "%02d:%02d", hour, minute)
    }

    private func parseTime(_ value: String?) -> DateComponents? {
        guard let value, !value.isEmpty else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return DateComponents(hour: hour, minute: minute)
    }

    private func ensuredSession() async throws -> AuthUserSession? {
        if let currentSession {
            return currentSession
        }
        let restored = try await authService.restoreSession()
        currentSession = restored
        return restored
    }

    private func runSafeRealtimeRefresh(for householdId: UUID) async {
        if isRealtimeRefreshInFlight {
            hasPendingRealtimeRefresh = true
            return
        }
        isRealtimeRefreshInFlight = true
        defer { isRealtimeRefreshInFlight = false }
        await refreshChildren(householdId: householdId)
        if hasPendingRealtimeRefresh {
            hasPendingRealtimeRefresh = false
            await refreshChildren(householdId: householdId)
        }
    }
    
    func reset() {
        children = []
        activities = []
        isLoading = false
        lastError = nil
        currentSession = nil
        realtimeDebounceTask?.cancel()
        realtimeDebounceTask = nil
        isRealtimeRefreshInFlight = false
        hasPendingRealtimeRefresh = false
    }
}
