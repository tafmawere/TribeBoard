import Foundation

struct BackendHousehold: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var inviteCode: String?
    var createdBy: UUID?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case inviteCode = "invite_code"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct BackendHouseholdMembership: Identifiable, Codable, Equatable {
    let id: UUID
    var householdId: UUID
    var userId: UUID
    var role: String
    var status: String?
    var accessRole: String
    var familyRole: String?
    var relationshipLabel: String?
    var invitedByUserId: UUID?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case userId = "user_id"
        case role
        case status
        case accessRole = "access_role"
        case familyRole = "family_role"
        case relationshipLabel = "relationship_label"
        case invitedByUserId = "invited_by_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum HouseholdMembershipStatus: String, CaseIterable {
    case pending
    case active
    case rejected
    case declined
    case revoked
    case removed
    case cancelled
    case inactive
}

extension BackendHouseholdMembership {
    var normalizedStatus: HouseholdMembershipStatus? {
        guard let value = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              let normalized = HouseholdMembershipStatus(rawValue: value) else {
            return nil
        }
        return normalized
    }

    var normalizedAccessRole: HouseholdAccessRole? {
        HouseholdAccessRole(rawValue: accessRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    var isPendingApproval: Bool {
        normalizedStatus == .pending
    }

    var isActive: Bool {
        isActiveMembership
    }

    /// Active membership grants household access. Excludes pending, revoked, removed, cancelled, inactive, and other non-active states.
    var isActiveMembership: Bool {
        guard let raw = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else {
            return true
        }
        return raw == HouseholdMembershipStatus.active.rawValue
    }

    var isRejected: Bool {
        normalizedStatus == .rejected
    }

    var isRevoked: Bool {
        normalizedStatus == .revoked
    }
}

enum HouseholdMemberRemovalPolicy {
    struct Evaluation: Equatable {
        let canRemove: Bool
        let blockedReason: String?
        let requiresOrganiserRemovalWarning: Bool
    }

    static func evaluate(
        membership: BackendHouseholdMembership,
        activeMembers: [BackendHouseholdMembership]
    ) -> Evaluation {
        guard membership.isActive else {
            return Evaluation(
                canRemove: false,
                blockedReason: "Only active members can be removed.",
                requiresOrganiserRemovalWarning: false
            )
        }

        let activeOrganisers = activeMembers.filter { $0.normalizedAccessRole == .organiser }
        if membership.normalizedAccessRole == .organiser, activeOrganisers.count <= 1 {
            return Evaluation(
                canRemove: false,
                blockedReason: "Cannot remove the last organiser in this household.",
                requiresOrganiserRemovalWarning: false
            )
        }

        return Evaluation(
            canRemove: true,
            blockedReason: nil,
            requiresOrganiserRemovalWarning: membership.normalizedAccessRole == .organiser
        )
    }
}

enum HouseholdAccessRole: String, CaseIterable {
    case organiser
    case driver
    case observer
}

enum AccessRole: String, CaseIterable {
    case organiser
    case driver
    case observer
}

enum InviteStatus: String, CaseIterable {
    case pending
    case accepted
    case cancelled
    case declined
    case expired
}

/// Invite preview for join UI (built from `household_invites` REST rows).
struct HouseholdInvitePreview: Decodable, Equatable {
    let inviteId: UUID
    let householdId: UUID
    let householdName: String
    let inviterDisplayName: String
    let accessRole: String
    let relationship: String?
    let status: String
    let expiresAt: String?
    let inviteToken: UUID?
    let backupInviteCode: String?

    enum CodingKeys: String, CodingKey {
        case inviteId = "invite_id"
        case householdId = "household_id"
        case householdName = "household_name"
        case inviterDisplayName = "inviter_display_name"
        case accessRole = "access_role"
        case relationship
        case status
        case expiresAt = "expires_at"
        case inviteToken = "invite_token"
        case backupInviteCode = "backup_invite_code"
    }

    var normalizedInviteStatus: InviteStatus? {
        InviteStatus(rawValue: status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    var isPendingAndNotExpired: Bool {
        guard normalizedInviteStatus == .pending else { return false }
        if let expiresAt,
           let parsed = BackendTimestampParser.parse(expiresAt),
           parsed < Date() {
            return false
        }
        return true
    }

    func asSyntheticHousehold() -> BackendHousehold {
        BackendHousehold(
            id: householdId,
            name: householdName,
            inviteCode: nil,
            createdBy: nil,
            createdAt: nil
        )
    }

    func toBackendInvite(email: String) -> BackendHouseholdInvite {
        BackendHouseholdInvite(
            id: inviteId,
            householdId: householdId,
            email: email,
            inviteCode: backupInviteCode,
            inviteToken: inviteToken?.uuidString.lowercased(),
            role: nil,
            accessRole: accessRole,
            relationship: relationship,
            status: status,
            invitedBy: nil,
            expiresAt: expiresAt,
            claimedByUserId: nil,
            claimedAt: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }
}

struct HouseholdInviteAcceptRPCResponse: Decodable, Equatable {
    let outcome: String
    let householdId: UUID?
    let householdName: String?

    enum CodingKeys: String, CodingKey {
        case outcome
        case householdId = "household_id"
        case householdName = "household_name"
    }
}

enum AuthBackedMemberDisplayResolver {
    static func resolveName(
        profile: BackendProfile?,
        relationshipLabel: String?
    ) -> String {
        if let displayName = profile?.display_name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        let first = profile?.first_name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = profile?.last_name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first, !first.isEmpty, let last, !last.isEmpty {
            return "\(first) \(last)"
        }
        if let first, !first.isEmpty {
            return first
        }
        if let email = profile?.email?.trimmingCharacters(in: .whitespacesAndNewlines),
           !email.isEmpty {
            return email
        }
        if let relationshipLabel = relationshipLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !relationshipLabel.isEmpty {
            return relationshipLabel
        }
        return "Member"
    }
}

struct BackendHouseholdInvite: Identifiable, Codable, Equatable {
    let id: UUID
    var householdId: UUID
    var email: String
    var inviteCode: String?
    var inviteToken: String?
    var role: String?
    var accessRole: String
    var relationship: String?
    var status: String
    var invitedBy: UUID?
    var expiresAt: String?
    var claimedByUserId: UUID?
    var claimedAt: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case email
        case inviteCode = "invite_code"
        case inviteToken = "invite_token"
        case role
        case accessRole = "access_role"
        case relationship
        case status
        case invitedBy = "invited_by"
        case expiresAt = "expires_at"
        case claimedByUserId = "claimed_by_user_id"
        case claimedAt = "claimed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension BackendHouseholdInvite {
    var normalizedAccessRole: AccessRole {
        let normalized = accessRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return AccessRole(rawValue: normalized) ?? .observer
    }

    var normalizedStatus: InviteStatus? {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return InviteStatus(rawValue: normalized)
    }
}

extension HouseholdInvitePreview {
    var normalizedAccessRole: AccessRole {
        let normalized = accessRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return AccessRole(rawValue: normalized) ?? .observer
    }
}

enum BackendTimestampParser {
    static func parse(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFractional.date(from: value) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let fallbackFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ssXXXXX"
        ]
        for format in fallbackFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: value) {
            return date
        }
        return nil
    }

    static func formatDateOnly(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
