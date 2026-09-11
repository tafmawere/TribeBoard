import Foundation

struct AssignDriverCandidate: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let role: String
    let source: Source

    enum Source: String, Equatable {
        case householdMembership
        case householdPerson
    }

    func asBackendDriver(householdId: UUID) -> BackendDriver {
        BackendDriver(
            id: id,
            householdId: householdId,
            userId: source == .householdMembership ? id : nil,
            displayName: displayName,
            role: role
        )
    }
}

enum AssignDriverEligibility {
    static func resolve(
        activeHouseholdId: UUID,
        memberships: [BackendHouseholdMembership],
        profilesByUserId: [UUID: BackendProfile],
        householdPeople: [BackendHouseholdPerson],
        childIds: Set<UUID>,
        currentUserId: UUID?
    ) -> [AssignDriverCandidate] {
        var byId: [UUID: AssignDriverCandidate] = [:]

        for membership in memberships where membership.householdId == activeHouseholdId {
            guard membership.isActiveMembership else { continue }
            guard isEligibleMembership(membership, currentUserId: currentUserId) else { continue }

            let profile = profilesByUserId[membership.userId]
            let name = AssignDriverCandidateDisplayName.resolve(
                profile: profile,
                relationshipLabel: membership.relationshipLabel,
                householdPersonName: nil
            )
            let role = membership.normalizedAccessRole?.rawValue ?? membership.accessRole
            byId[membership.userId] = AssignDriverCandidate(
                id: membership.userId,
                displayName: name,
                role: role,
                source: .householdMembership
            )
        }

        for person in householdPeople where person.householdId == activeHouseholdId {
            guard !childIds.contains(person.id) else { continue }
            guard isEligibleHouseholdPerson(person) else { continue }
            if byId[person.id] != nil { continue }
            byId[person.id] = AssignDriverCandidate(
                id: person.id,
                displayName: AssignDriverCandidateDisplayName.resolve(
                    profile: nil,
                    relationshipLabel: nil,
                    householdPersonName: person.name
                ),
                role: person.isDriver ? "driver" : person.role,
                source: .householdPerson
            )
        }

        return byId.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private static func isEligibleMembership(
        _ membership: BackendHouseholdMembership,
        currentUserId: UUID?
    ) -> Bool {
        if membership.userId == currentUserId {
            return true
        }
        switch membership.normalizedAccessRole {
        case .organiser, .driver:
            return true
        case .observer, .none:
            break
        }
        let familyRole = membership.familyRole?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let role = membership.role
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return ["parent", "guardian"].contains(familyRole)
            || ["parent", "guardian"].contains(role)
    }

    private static func isEligibleHouseholdPerson(_ person: BackendHouseholdPerson) -> Bool {
        let role = person.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if role == "child" { return false }
        if person.isDriver { return true }
        return ["parent", "guardian", "driver"].contains(role)
    }
}

enum AssignDriverCandidateDisplayName {
    static func resolve(
        profile: BackendProfile?,
        relationshipLabel: String?,
        householdPersonName: String?
    ) -> String {
        if let displayName = profile?.display_name?.trimmedNonEmpty {
            return displayName
        }
        if let relationshipLabel = relationshipLabel?.trimmedNonEmpty {
            return relationshipLabel
        }
        let fullName = [profile?.first_name, profile?.last_name]
            .compactMap { $0?.trimmedNonEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullName.isEmpty {
            return fullName
        }
        if let householdPersonName = householdPersonName?.trimmedNonEmpty {
            return householdPersonName
        }
        if let email = profile?.email?.trimmedNonEmpty {
            return email
        }
        return "Driver"
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
