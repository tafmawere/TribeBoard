import Foundation

enum MembershipError: Error {
    case notAuthorizedOrNotFound
}

func formatHouseholdJoinCode(householdId: UUID) -> String {
    "H-\(String(householdId.uuidString.prefix(8)).uppercased())"
}

func parseHouseholdJoinCode(_ input: String) -> String? {
    let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let pattern = #"^H-[A-F0-9]{8}$"#
    guard normalized.range(of: pattern, options: .regularExpression) != nil else {
        return nil
    }
    return String(normalized.dropFirst(2))
}

func generateHouseholdInviteCode(length: Int = 8) -> String {
    let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    let clampedLength = min(max(length, 6), 10)
    var value = ""
    value.reserveCapacity(clampedLength)
    for _ in 0..<clampedLength {
        guard let scalar = alphabet.randomElement() else { continue }
        value.append(scalar)
    }
    return value
}

protocol HouseholdBackendService {
    func createHousehold(name: String, session: AuthUserSession) async throws -> BackendHousehold
    func updateHouseholdName(householdId: UUID, name: String, session: AuthUserSession) async throws -> BackendHousehold
    func fetchMyHouseholds(session: AuthUserSession) async throws -> [BackendHousehold]
    func fetchMyMemberships(session: AuthUserSession) async throws -> [BackendHouseholdMembership]
    func createInviteCode(for householdId: UUID, session: AuthUserSession) async throws -> BackendHouseholdInvite
    func createInviteOrPendingMembership(
        householdId: UUID,
        email: String,
        accessRole: String,
        relationshipLabel: String?,
        invitedByUserId: UUID?,
        session: AuthUserSession
    ) async throws -> InviteOrMembershipCreateResult
    func fetchInvites(householdId: UUID, session: AuthUserSession) async throws -> [BackendHouseholdInvite]
    func resendInviteEmail(invite: BackendHouseholdInvite, household: BackendHousehold, session: AuthUserSession) async throws
    func cancelInvite(inviteId: UUID, session: AuthUserSession) async throws
    func fetchPendingInvitesForSignedInUser(session: AuthUserSession) async throws -> [BackendHouseholdInvite]
    func acceptPendingInvitesForSignedInUser(session: AuthUserSession) async throws
    func approveMembership(membershipId: UUID, session: AuthUserSession) async throws -> BackendHouseholdMembership
    func approveMembershipRequest(membershipId: UUID, session: AuthUserSession) async throws
    func rejectMembershipRequest(membershipId: UUID, session: AuthUserSession) async throws
    func updateMembershipAccess(
        membershipId: UUID,
        accessRole: String,
        relationshipLabel: String?,
        session: AuthUserSession
    ) async throws -> BackendHouseholdMembership
    func removeHouseholdMember(membershipId: UUID, session: AuthUserSession) async throws -> BackendHouseholdMembership
    func resolveHouseholdByJoinCode(prefix: String, session: AuthUserSession) async throws -> [BackendHousehold]
    func fetchHouseholdByInviteCode(_ code: String, session: AuthUserSession) async throws -> BackendHousehold
    func fetchInvitePreviewByCode(_ code: String, session: AuthUserSession?) async throws -> HouseholdInvitePreview?
    func fetchInvitePreviewByToken(_ token: String, session: AuthUserSession?) async throws -> HouseholdInvitePreview?
    func fetchInvitePreviewByInviteId(_ inviteId: UUID, session: AuthUserSession?) async throws -> HouseholdInvitePreview?
    func inspectJoinByInviteCode(_ code: String, session: AuthUserSession?) async throws -> InviteCodeJoinResult
    func hasPendingInviteForSignedInUser(householdId: UUID, session: AuthUserSession) async throws -> Bool
    func joinHouseholdByInviteCode(_ code: String, session: AuthUserSession) async throws -> BackendHousehold
    func joinHouseholdByCode(_ code: String, session: AuthUserSession) async throws -> BackendHousehold
    func acceptHouseholdInviteRPC(inviteCode: String, session: AuthUserSession) async throws -> HouseholdInviteAcceptRPCResponse
    func acceptHouseholdInviteRPC(inviteToken: String, session: AuthUserSession) async throws -> HouseholdInviteAcceptRPCResponse
    func acceptHouseholdInviteRPC(inviteId: UUID, session: AuthUserSession) async throws -> HouseholdInviteAcceptRPCResponse
    func declineHouseholdInviteRPC(inviteCode: String, session: AuthUserSession) async throws -> HouseholdInviteAcceptRPCResponse
    func fetchHouseholdMembers(householdId: UUID, session: AuthUserSession) async throws -> [BackendHouseholdMembership]
    func updateMembershipAttributes(
        membershipId: UUID,
        role: String?,
        status: String?,
        familyRole: String?,
        relationshipLabel: String?,
        session: AuthUserSession
    ) async throws -> BackendHouseholdMembership
}

enum InviteOrMembershipCreateResult {
    case existingMember(BackendHouseholdMembership)
    case pendingMembershipCreated(BackendHouseholdMembership)
    case inviteCreated(BackendHouseholdInvite)
    case existingPendingInvite(BackendHouseholdInvite)
}

enum InviteCodeJoinResult {
    /// A pending `household_invites` row matches this code; join completes immediately.
    case matchedInvite(BackendHousehold)
    /// Code matches the household's public `households.invite_code` only; join requests observer approval.
    case noInviteExists(BackendHousehold)

    var household: BackendHousehold {
        switch self {
        case .matchedInvite(let household),
             .noInviteExists(let household):
            return household
        }
    }
}

struct SupabaseHouseholdBackendService: HouseholdBackendService {
    private let authService: AuthService

    init(authService: AuthService = SupabaseAuthService()) {
        self.authService = authService
    }

    enum ServiceError: LocalizedError {
        case backendNotConfigured
        case invalidUserId
        case invalidJoinCodeFormat
        case joinCodeNotFound
        case joinCodeAmbiguous
        case inviteExpired
        case inviteAlreadyClaimed
        case inviteCancelled
        case inviteDeclined
        case inviteNotFound
        case alreadyMember
        case noHouseholds
        case sessionExpired
        case cancelInviteNoRowsUpdated
        case cannotRemoveMember(String)
        case permissionDenied(action: String, role: String)
        case requestFailed(String)
        case inviteConnectionFailed

        var errorDescription: String? {
            switch self {
            case .backendNotConfigured:
                return "Backend is not configured."
            case .invalidUserId:
                return "Authenticated user id is not a valid UUID."
            case .invalidJoinCodeFormat:
                return "Enter a valid family code."
            case .joinCodeNotFound:
                return "This invite code does not exist."
            case .joinCodeAmbiguous:
                return "This code matches more than one family. Please try again."
            case .inviteExpired:
                return "This invite has expired."
            case .inviteAlreadyClaimed:
                return "This invite has already been used."
            case .inviteCancelled:
                return "This invite was cancelled by the organiser."
            case .inviteDeclined:
                return "This invite is no longer available."
            case .inviteNotFound:
                return "This invite code does not exist."
            case .alreadyMember:
                return "You are already a member of this household."
            case .noHouseholds:
                return "No households found."
            case .sessionExpired:
                return "Session expired. Please sign in again to continue."
            case .cancelInviteNoRowsUpdated:
                return "Could not cancel this invite. Please try again."
            case .cannotRemoveMember(let reason):
                return reason
            case .permissionDenied(let action, let role):
                return "Permission denied for \(action). Role \(role) is not allowed."
            case .requestFailed(let message):
                return Self.userFacingMessage(forRequestFailure: message)
            case .inviteConnectionFailed:
                return Self.inviteConnectionFailedMessage
            }
        }

        static let inviteConnectionFailedMessage =
            "We could not connect you to this family invite. Please ask the organiser to resend the invite."

        static func userFacingInviteJoinMessage(for error: Error) -> String {
            if let serviceError = error as? ServiceError {
                return serviceError.localizedDescription
                    ?? inviteConnectionFailedMessage
            }
            let text = error.localizedDescription
            if text.contains("PGRST")
                || text.contains("POST failed")
                || text.contains("get_invite_by_code")
                || text.contains("Could not find function") {
                return inviteConnectionFailedMessage
            }
            return text.isEmpty ? inviteConnectionFailedMessage : text
        }

        private static func userFacingMessage(forRequestFailure message: String) -> String {
            let normalized = message.lowercased()
            if normalized.contains("pgrst")
                || normalized.contains("post failed")
                || normalized.contains("get_invite_by_code")
                || normalized.contains("could not find function") {
                return inviteConnectionFailedMessage
            }
            return message
        }
    }

    private struct EmptyResponse: Decodable {}

    private struct CreateMembershipRequest: Encodable {
        let household_id: UUID
        let user_id: UUID
        let role: String
        let status: String
        let access_role: String
        let family_role: String?
        let relationship_label: String?
        let invited_by_user_id: UUID?
        let created_at: String
        let updated_at: String
    }

    private struct UpdateHouseholdNameRequest: Encodable {
        let name: String
        let updated_at: String
    }

    private struct CreateHouseholdRequest: Encodable {
        let id: UUID
        let name: String
        let created_by: UUID
        let invite_code: String
    }

    private struct UpdateHouseholdInviteCodeRequest: Encodable {
        let invite_code: String
    }

    private struct UpdateMembershipAttributesRequest: Encodable {
        let role: String?
        let status: String?
        let family_role: String?
        let relationship_label: String?
    }

    private struct CreateInviteRequest: Encodable {
        let household_id: UUID
        let invite_code: String
        let invite_token: String
        let email: String
        let access_role: String
        let relationship: String?
        let status: String
        let invited_by: UUID?
        let expires_at: String
    }

    private struct UpdateInviteClaimRequest: Encodable {
        let status: String
        let claimed_by_user_id: UUID
        let claimed_at: String
        let updated_at: String
    }

    private struct UpdateInviteStatusRequest: Encodable {
        let status: String
        let updated_at: String
    }

    private struct SendInviteEmailRequest: Encodable {
        let email: String
        let household_id: String
        let invite_id: String
        let tribe_name: String
        let invite_code: String
        let invite_token: String?
        let access_role: String
        let relationship: String
        let invite_url: String
        let inviter_display_name: String?
    }

    private struct UpdateMembershipAccessRequest: Encodable {
        let access_role: String
        let relationship_label: String?
        let updated_at: String
    }

    private struct UpdateMembershipStatusRequest: Encodable {
        let status: String
        let updated_at: String
    }

    private struct WriteDiagnosticContext {
        let operation: String
        let tableOrEndpoint: String
        let payloadSummary: String
    }

    private struct ResolveByJoinCodeRPCPayload: Encodable {
        let code_prefix: String
    }

    private struct GetInviteByCodeRPCRequest: Encodable {
        let p_code: String
    }

    private struct GetInviteByTokenRPCRequest: Encodable {
        let p_token: String
    }

    private struct GetInviteByIdRPCRequest: Encodable {
        let p_invite_id: UUID
    }

    private struct EmptyRPCBody: Encodable {}

    private struct AcceptInviteByCodeRPCRequest: Encodable {
        let p_code: String
    }

    private struct AcceptInviteByTokenRPCRequest: Encodable {
        let p_token: String
    }

    private struct AcceptInviteByIdRPCRequest: Encodable {
        let p_invite_id: UUID
    }

    private struct DeclineInviteRPCRequest: Encodable {
        let p_code: String
    }

    private struct RefreshTokenResponse: Decodable {
        let access_token: String?
        let refresh_token: String?
        let expires_in: Int?
        let user: RefreshUser?

        struct RefreshUser: Decodable {
            let id: String?
            let email: String?
        }
    }

    private struct HouseholdInviteEmailContextResponse: Decodable {
        let name: String
        let inviteCode: String?

        enum CodingKeys: String, CodingKey {
            case name
            case inviteCode = "invite_code"
        }
    }

    private struct HouseholdIdResponse: Decodable {
        let id: UUID
    }

    func createHousehold(name: String, session: AuthUserSession) async throws -> BackendHousehold {
        guard BackendConfig.isSupabaseConfigured else {
            throw ServiceError.backendNotConfigured
        }
        guard let userId = UUID(uuidString: session.userId) else {
            throw ServiceError.invalidUserId
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let householdId = UUID()
        let inviteCode = try await nextAvailableHouseholdInviteCode(session: session)
        let payload = [CreateHouseholdRequest(
            id: householdId,
            name: trimmed,
            created_by: userId,
            invite_code: inviteCode
        )]
        let url = try SupabaseClientProvider.restURL(path: "households")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try authenticatedHeaders(
            session: session,
            request: request,
            operation: "createHousehold",
            tableOrEndpoint: "households",
            payloadSummary: "name=\(trimmed), created_by=\(userId.uuidString)"
        )
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(payload)
        _ = try await perform(
            request,
            writeContext: WriteDiagnosticContext(
                operation: "createHousehold",
                tableOrEndpoint: "households",
                payloadSummary: "name=\(trimmed), created_by=\(userId.uuidString)"
            )
        ) as EmptyResponse

        do {
            let membershipURL = try SupabaseClientProvider.restURL(path: "household_memberships")
            var membershipRequest = URLRequest(url: membershipURL)
            membershipRequest.httpMethod = "POST"
            membershipRequest.allHTTPHeaderFields = try authenticatedHeaders(
                session: session,
                request: membershipRequest,
                operation: "createHousehold",
                tableOrEndpoint: "household_memberships",
                payloadSummary: "household_id=\(householdId.uuidString), user_id=\(userId.uuidString), role=admin"
            )
            membershipRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            membershipRequest.httpBody = try JSONEncoder().encode([CreateMembershipRequest(
                household_id: householdId,
                user_id: userId,
                role: "parent",
                status: "active",
                access_role: HouseholdAccessRole.organiser.rawValue,
                family_role: "parent",
                relationship_label: nil,
                invited_by_user_id: nil,
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date())
            )])
            _ = try await perform(
                membershipRequest,
                writeContext: WriteDiagnosticContext(
                    operation: "createHousehold",
                    tableOrEndpoint: "household_memberships",
                    payloadSummary: "household_id=\(householdId.uuidString), user_id=\(userId.uuidString), role=admin"
                )
            ) as EmptyResponse
        } catch {
            throw ServiceError.requestFailed(
                "Household row was created, but membership creation failed. \(error.localizedDescription)"
            )
        }

        return BackendHousehold(
            id: householdId,
            name: trimmed,
            inviteCode: inviteCode,
            createdBy: userId,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    func updateHouseholdName(householdId: UUID, name: String, session: AuthUserSession) async throws -> BackendHousehold {
        guard BackendConfig.isSupabaseConfigured else {
            throw ServiceError.backendNotConfigured
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.requestFailed("Family name is required.")
        }
        let payload = UpdateHouseholdNameRequest(
            name: trimmed,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        let rows: [BackendHousehold] = try await patch(
            path: "households?id=eq.\(householdId.uuidString)",
            payload: payload,
            session: session,
            context: WriteDiagnosticContext(
                operation: "updateHouseholdName",
                tableOrEndpoint: "households",
                payloadSummary: "household_id=\(householdId.uuidString), name=\(trimmed)"
            )
        )
        guard let updated = rows.first else {
            throw ServiceError.requestFailed("Failed to update household name.")
        }
        return updated
    }

    func fetchMyHouseholds(session: AuthUserSession) async throws -> [BackendHousehold] {
        let memberships = try await fetchMyMemberships(session: session)
        let ids = memberships.filter(\.isActiveMembership).map(\.householdId)
        guard !ids.isEmpty else { return [] }
        let idFilter = ids.map(\.uuidString).joined(separator: ",")
        let path = "households?select=*&id=in.(\(idFilter))&order=created_at.asc"
        let households: [BackendHousehold] = try await get(path: path, session: session)
        var normalizedHouseholds: [BackendHousehold] = []
        normalizedHouseholds.reserveCapacity(households.count)
        for var household in households {
            if household.inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                let generatedCode = try await ensureInviteCode(for: household.id, session: session)
                household.inviteCode = generatedCode
            } else {
                household.inviteCode = household.inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            }
            normalizedHouseholds.append(household)
        }
        return normalizedHouseholds
    }

    func fetchMyMemberships(session: AuthUserSession) async throws -> [BackendHouseholdMembership] {
        guard let userId = UUID(uuidString: session.userId) else {
            throw ServiceError.invalidUserId
        }
        let path = "household_memberships?select=*&user_id=eq.\(userId.uuidString)&order=created_at.asc"
        let memberships: [BackendHouseholdMembership] = try await get(path: path, session: session)
        return memberships
    }

    func createInviteCode(for householdId: UUID, session: AuthUserSession) async throws -> BackendHouseholdInvite {
        guard let userId = UUID(uuidString: session.userId) else {
            throw ServiceError.invalidUserId
        }
        try await requireOrganiserPermission(
            householdId: householdId,
            session: session,
            action: "createInviteCode"
        )
        let syntheticEmail = "invite+\(UUID().uuidString.lowercased())@tribeboard.local"
        let inviteCode = try await nextUniqueInviteCode(session: session)
        let inviteToken = UUID().uuidString.lowercased()
        let expiresAt = Self.defaultInviteExpiresAtISO8601()
        let payload = [CreateInviteRequest(
            household_id: householdId,
            invite_code: inviteCode,
            invite_token: inviteToken,
            email: syntheticEmail,
            access_role: HouseholdAccessRole.observer.rawValue,
            relationship: nil,
            status: InviteStatus.pending.rawValue,
            invited_by: userId,
            expires_at: expiresAt
        )]
#if DEBUG
        print("Invite payload:", [
            "household_id": householdId.uuidString,
            "invite_code": inviteCode,
            "invite_token": inviteToken,
            "email": syntheticEmail,
            "access_role": HouseholdAccessRole.observer.rawValue,
            "relationship": "nil",
            "invited_by": userId.uuidString,
            "status": InviteStatus.pending.rawValue,
            "expires_at": expiresAt
        ])
#endif
        let invites: [BackendHouseholdInvite] = try await post(
            table: "household_invites",
            payload: payload,
            session: session,
            context: WriteDiagnosticContext(
                operation: "createInviteCode",
                tableOrEndpoint: "household_invites",
                payloadSummary: "household_id=\(householdId.uuidString), invite_code=\(inviteCode), email=\(syntheticEmail), access_role=observer, status=pending"
            )
        )
        guard let invite = invites.first else {
            throw ServiceError.requestFailed("Failed to create invite code.")
        }
        InviteFlowLogger.inviteRowCreated(
            inviteId: invite.id,
            householdId: householdId,
            invitedEmail: syntheticEmail,
            authUserId: session.userId,
            inviteCode: inviteCode,
            inviteToken: inviteToken
        )
#if DEBUG
        print(
            "[HouseholdBackendService] createInviteCode generated invite_code=\(inviteCode) " +
            "invite_token=\(inviteToken) household_id=\(householdId.uuidString) " +
            "(per-invite code is not written to households.invite_code)"
        )
#endif
        return invite
    }

    func createInviteOrPendingMembership(
        householdId: UUID,
        email: String,
        accessRole: String,
        relationshipLabel: String?,
        invitedByUserId: UUID?,
        session: AuthUserSession
    ) async throws -> InviteOrMembershipCreateResult {
        try await requireOrganiserPermission(
            householdId: householdId,
            session: session,
            action: "createInviteOrPendingMembership"
        )
        let normalizedEmail = normalizeEmail(email)
        guard !normalizedEmail.isEmpty else {
            throw ServiceError.requestFailed("Invite email is required.")
        }
        guard let normalizedAccessRole = normalizeAccessRole(accessRole) else {
            throw ServiceError.requestFailed("Invalid access role.")
        }
        let normalizedRelationshipLabel = normalizeRelationshipLabel(relationshipLabel)
#if DEBUG
        print(
            "[HouseholdBackendService] invite create start household_id=\(householdId.uuidString), " +
            "email=\(normalizedEmail), access_role=\(normalizedAccessRole)"
        )
#endif

        let matchedProfile = try await fetchProfileByEmail(normalizedEmail, session: session)
        if let matchedProfile {
#if DEBUG
            print(
                "[HouseholdBackendService] existing profile matched email=\(normalizedEmail), " +
                "profile_id=\(matchedProfile.id.uuidString)"
            )
#endif
            try await consumePendingInvitesForEmail(
                householdId: householdId,
                email: normalizedEmail,
                claimedByUserId: matchedProfile.id,
                session: session
            )
            if let existingMembership = try await fetchMembership(householdId: householdId, userId: matchedProfile.id, session: session) {
#if DEBUG
                print(
                    "[HouseholdBackendService] existing membership found household_id=\(householdId.uuidString), " +
                    "user_id=\(matchedProfile.id.uuidString)"
                )
#endif
                return .existingMember(existingMembership)
            }

            let now = ISO8601DateFormatter().string(from: Date())
            let createdMemberships: [BackendHouseholdMembership] = try await post(
                table: "household_memberships",
                payload: [CreateMembershipRequest(
                    household_id: householdId,
                    user_id: matchedProfile.id,
                    role: "member",
                    status: "active",
                    access_role: normalizedAccessRole,
                    family_role: nil,
                    relationship_label: normalizedRelationshipLabel,
                    invited_by_user_id: invitedByUserId,
                    created_at: now,
                    updated_at: now
                )],
                session: session,
                context: WriteDiagnosticContext(
                    operation: "createInviteOrPendingMembership",
                    tableOrEndpoint: "household_memberships",
                    payloadSummary: "household_id=\(householdId.uuidString), user_id=\(matchedProfile.id.uuidString), status=active, access_role=\(normalizedAccessRole)"
                )
            )
            guard let createdMembership = createdMemberships.first else {
                throw ServiceError.requestFailed("Failed to create membership.")
            }
#if DEBUG
            print(
                "[HouseholdBackendService] active membership created household_id=\(householdId.uuidString), " +
                "membership_id=\(createdMembership.id.uuidString)"
            )
#endif
            return .pendingMembershipCreated(createdMembership)
        }

        if let existingInvite = try await fetchPendingInvite(
            householdId: householdId,
            email: normalizedEmail,
            session: session
        ) {
#if DEBUG
            print(
                "[HouseholdBackendService] existing pending invite found household_id=\(householdId.uuidString), " +
                "invite_id=\(existingInvite.id.uuidString), email=\(normalizedEmail)"
            )
#endif
            return .existingPendingInvite(existingInvite)
        }

        let inviteCode = try await nextUniqueInviteCode(session: session)
        let inviteToken = UUID().uuidString.lowercased()
        let expiresAt = Self.defaultInviteExpiresAtISO8601()
        let invitePayload = CreateInviteRequest(
            household_id: householdId,
            invite_code: inviteCode,
            invite_token: inviteToken,
            email: normalizedEmail,
            access_role: normalizedAccessRole,
            relationship: normalizedRelationshipLabel,
            status: InviteStatus.pending.rawValue,
            invited_by: invitedByUserId,
            expires_at: expiresAt
        )
#if DEBUG
        print("Invite payload:", [
            "household_id": householdId.uuidString,
            "invite_code": inviteCode,
            "invite_token": inviteToken,
            "email": normalizedEmail,
            "access_role": normalizedAccessRole,
            "relationship": normalizedRelationshipLabel ?? "nil",
            "invited_by": invitedByUserId?.uuidString ?? "nil",
            "status": InviteStatus.pending.rawValue,
            "expires_at": expiresAt
        ])
#endif
        let createdInvites: [BackendHouseholdInvite] = try await post(
            table: "household_invites",
            payload: [invitePayload],
            session: session,
            context: WriteDiagnosticContext(
                operation: "createInviteOrPendingMembership",
                tableOrEndpoint: "household_invites",
                payloadSummary: "household_id=\(householdId.uuidString), email=\(normalizedEmail), access_role=\(normalizedAccessRole), status=pending"
            )
        )
        guard let createdInvite = createdInvites.first else {
            throw ServiceError.requestFailed("Failed to create invite.")
        }
        InviteFlowLogger.inviteRowCreated(
            inviteId: createdInvite.id,
            householdId: householdId,
            invitedEmail: normalizedEmail,
            authUserId: session.userId,
            inviteCode: inviteCode,
            inviteToken: inviteToken
        )
#if DEBUG
        print(
            "[HouseholdBackendService] invite row created household_id=\(householdId.uuidString), " +
            "invite_id=\(createdInvite.id.uuidString), email=\(normalizedEmail)"
        )
#endif
        var inviteForEmail = createdInvite
        if inviteForEmail.inviteToken?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            inviteForEmail.inviteToken = inviteToken
        }
        await sendInviteEmailAfterCreation(
            invite: inviteForEmail,
            accessRole: normalizedAccessRole,
            relationship: normalizedRelationshipLabel,
            session: session
        )
        return .inviteCreated(createdInvite)
    }

    func fetchInvites(householdId: UUID, session: AuthUserSession) async throws -> [BackendHouseholdInvite] {
        let path = "household_invites?select=*&household_id=eq.\(householdId.uuidString)&order=created_at.desc"
        return try await get(path: path, session: session)
    }

    func resendInviteEmail(invite: BackendHouseholdInvite, household: BackendHousehold, session: AuthUserSession) async throws {
        try await requireOrganiserPermission(
            householdId: household.id,
            session: session,
            action: "resendInviteEmail"
        )
        let householdName = household.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let tribeName = householdName.isEmpty ? "TribeBoard" : householdName
        let rowInviteCode = invite.inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let existingInviteCode = household.inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let inviteCode: String
        if let rowInviteCode, !rowInviteCode.isEmpty {
            inviteCode = rowInviteCode
        } else if let existingInviteCode, !existingInviteCode.isEmpty {
            inviteCode = existingInviteCode
        } else {
            inviteCode = try await ensureInviteCode(for: household.id, session: session)
        }
        let accessRole = normalizeAccessRole(invite.accessRole) ?? HouseholdAccessRole.observer.rawValue
        let relationship = normalizeRelationshipLabel(invite.relationship)
#if DEBUG
        print("[Invite] resend_start invite_id=\(invite.id.uuidString), email=\(invite.email)")
#endif
        do {
            try await sendInviteEmailRequest(
                invite: invite,
                tribeName: tribeName,
                inviteCode: inviteCode,
                accessRole: accessRole,
                relationship: relationship,
                session: session,
                logPrefix: "resendInviteEmail"
            )
        } catch {
            InviteFlowLogger.inviteEmailHTTPResult(
                inviteId: invite.id,
                householdId: invite.householdId,
                invitedEmail: invite.email,
                authUserId: session.userId,
                success: false,
                statusCode: nil,
                logPrefix: "resendInviteEmail"
            )
#if DEBUG
            print("[Invite] resend_failure invite_id=\(invite.id.uuidString), email=\(invite.email), error=\(error.localizedDescription)")
#endif
            throw error
        }
#if DEBUG
        print("[Invite] resend_success invite_id=\(invite.id.uuidString), email=\(invite.email)")
#endif
    }

    func cancelInvite(inviteId: UUID, session: AuthUserSession) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let normalizedInviteId = inviteId.uuidString.lowercased()
        let patchPath = "household_invites?id=eq.\(normalizedInviteId)&select=*"
        let inviteBeforeUpdate = try await fetchInviteById(inviteId: inviteId, session: session)
        guard let inviteHouseholdId = inviteBeforeUpdate?.householdId else {
            throw ServiceError.requestFailed("Invite not found.")
        }
        try await requireOrganiserPermission(
            householdId: inviteHouseholdId,
            session: session,
            action: "cancelInvite"
        )
        let activeHouseholdId = inviteBeforeUpdate?.householdId.uuidString ?? "unknown"
        let payload = UpdateInviteStatusRequest(
            status: InviteStatus.cancelled.rawValue,
            updated_at: now
        )
#if DEBUG
        let patchURL = try SupabaseClientProvider.restURL(path: patchPath).absoluteString
        let payloadData = try JSONEncoder().encode(payload)
        let payloadJSON = String(data: payloadData, encoding: .utf8) ?? "{}"
        print("[HouseholdBackendService] cancel invite start invite_id=\(normalizedInviteId)")
        print("[HouseholdBackendService] cancel invite user_id=\(session.userId)")
        print("[HouseholdBackendService] cancel invite active_household_id=\(activeHouseholdId)")
        print("[HouseholdBackendService] cancel invite method=PATCH url=\(patchURL)")
        print("[HouseholdBackendService] cancel invite payload=\(payloadJSON)")
#endif
        let updatedRows: [BackendHouseholdInvite]
        do {
            updatedRows = try await patch(
                path: patchPath,
                payload: payload,
                session: session,
                context: WriteDiagnosticContext(
                    operation: "cancelInvite",
                    tableOrEndpoint: "household_invites",
                    payloadSummary: "invite_id=\(inviteId.uuidString), status=cancelled"
                )
            )
        } catch {
#if DEBUG
            let message = String(describing: error).lowercased()
            if message.contains("invalid input value for enum")
                || message.contains("check constraint")
                || message.contains("violates check constraint")
                || message.contains("status") {
                print("[HouseholdBackendService] Invalid invite status value")
            }
#endif
            throw error
        }
        guard let updated = updatedRows.first else {
            throw ServiceError.cancelInviteNoRowsUpdated
        }
        let normalizedStatus = updated.normalizedStatus
        guard normalizedStatus == .cancelled else {
            throw ServiceError.requestFailed("Cancel invite update did not persist cancelled status.")
        }
        if let reloaded = try await fetchInviteById(inviteId: inviteId, session: session) {
            guard reloaded.normalizedStatus == .cancelled else {
                throw ServiceError.requestFailed("Cancel invite verification failed. Invite status is still \(reloaded.status).")
            }
        } else {
            throw ServiceError.requestFailed("Cancel invite verification failed. Invite row not found after update.")
        }
#if DEBUG
        print("[HouseholdBackendService] cancel invite updated_rows=\(updatedRows.count) status=\(updated.status)")
        print("[HouseholdBackendService] cancel invite succeeded invite_id=\(normalizedInviteId)")
#endif
    }

    func fetchPendingInvitesForSignedInUser(session: AuthUserSession) async throws -> [BackendHouseholdInvite] {
        guard BackendConfig.isSupabaseConfigured else {
            throw ServiceError.backendNotConfigured
        }
        guard let normalizedEmail = try await resolveSignedInUserEmail(session: session), !normalizedEmail.isEmpty else {
#if DEBUG
            print("[Onboarding] auth_email=nil")
            print("[Onboarding] pending invite query by email count=0")
#endif
            return []
        }
#if DEBUG
        print("[Onboarding] auth_email=\(normalizedEmail)")
#endif
        var merged: [BackendHouseholdInvite] = []
        var seen = Set<UUID>()

        func appendUnique(_ invite: BackendHouseholdInvite) {
            guard seen.insert(invite.id).inserted else { return }
            merged.append(invite)
        }

        if let rpcInvites = try? await fetchPendingInvitesViaRPC(session: session, email: normalizedEmail) {
#if DEBUG
            print("[Onboarding] pending invite query by email count=\(rpcInvites.count)")
#endif
            rpcInvites.forEach { appendUnique($0) }
        } else {
            let encodedEmail = encodeQueryValue(normalizedEmail)
            let pendingInvitesPath =
                "household_invites?select=*&email=ilike.\(encodedEmail)&status=eq.\(InviteStatus.pending.rawValue)&order=created_at.asc"
#if DEBUG
            print("[HouseholdBackendService] pending_invites_query path=\(pendingInvitesPath)")
#endif
            let rows: [BackendHouseholdInvite] = (try? await get(path: pendingInvitesPath, session: session)) ?? []
#if DEBUG
            print("[Onboarding] pending invite query by email count=\(rows.count)")
#endif
            rows.forEach { appendUnique($0) }
        }

        if let snap = PendingInvitePersistence.load(), let inviteId = snap.inviteId {
            if let preview = try? await fetchInvitePreviewByInviteId(inviteId, session: session),
               preview.normalizedInviteStatus == .pending,
               preview.isPendingAndNotExpired {
                appendUnique(preview.toBackendInvite(email: snap.invitedEmail ?? normalizedEmail))
#if DEBUG
                print("[Onboarding] pending invite query by invite_id count=1")
                print("[Onboarding] pending invite query by invite_id invite_id=\(inviteId.uuidString)")
#endif
            } else if let row = try? await fetchInviteById(inviteId: inviteId, session: session),
                      row.normalizedStatus == .pending {
                appendUnique(row)
#if DEBUG
                print("[Onboarding] pending invite query by invite_id count=1")
#endif
            } else {
#if DEBUG
                print("[Onboarding] pending invite query by invite_id count=0")
#endif
            }
        }

        return merged.sorted {
            BackendTimestampParser.parse($0.createdAt) ?? .distantPast
                < BackendTimestampParser.parse($1.createdAt) ?? .distantPast
        }
    }

    func acceptPendingInvitesForSignedInUser(session: AuthUserSession) async throws {
        guard UUID(uuidString: session.userId) != nil else {
            throw ServiceError.invalidUserId
        }
        guard let normalizedEmail = try await resolveSignedInUserEmail(session: session), !normalizedEmail.isEmpty else {
            return
        }
#if DEBUG
        print("[InviteAccept] pipeline start email=\(normalizedEmail)")
#endif
        let pendingInvites = try await fetchPendingInvitesForSignedInUser(session: session)
        guard !pendingInvites.isEmpty else { return }

        var acceptedAnyViaRPC = false
        var failedInvites: [BackendHouseholdInvite] = []
        for invite in pendingInvites {
#if DEBUG
            print("[InviteAccept] selected_invite_id=\(invite.id.uuidString)")
            print("[InviteAccept] household_id=\(invite.householdId.uuidString)")
#endif
            if let response = try? await acceptPendingInviteViaRPC(invite: invite, session: session) {
                let outcome = response.outcome.lowercased()
#if DEBUG
                print("[InviteAccept] outcome=\(outcome)")
                print("[InviteAccept] invite marked accepted=\(outcome == "joined" || outcome == "already_member")")
                print("[InviteAccept] membership created=\(outcome == "joined" || outcome == "already_member")")
#endif
                if outcome == "joined" || outcome == "already_member" {
                    acceptedAnyViaRPC = true
                    continue
                }
                if outcome != "invalid_code" {
                    throw Self.serviceErrorFromAcceptOutcome(outcome)
                }
            }
            failedInvites.append(invite)
        }

        if acceptedAnyViaRPC, failedInvites.isEmpty { return }
        let restTargets = failedInvites.isEmpty ? pendingInvites : failedInvites
        try await acceptPendingInvitesViaREST(pendingInvites: restTargets, session: session)
    }

    func approveMembership(membershipId: UUID, session: AuthUserSession) async throws -> BackendHouseholdMembership {
        let membership = try await fetchMembershipById(membershipId: membershipId, session: session)
        try await requireOrganiserPermission(
            householdId: membership.householdId,
            session: session,
            action: "approveMembership"
        )
#if DEBUG
        print("[HouseholdBackendService] membership approval start membership_id=\(membershipId.uuidString)")
#endif
        let updated = try await patch(
            path: "household_memberships?id=eq.\(membershipId.uuidString)",
            payload: UpdateMembershipStatusRequest(
                status: "active",
                updated_at: ISO8601DateFormatter().string(from: Date())
            ),
            session: session,
            context: WriteDiagnosticContext(
                operation: "approveMembership",
                tableOrEndpoint: "household_memberships",
                payloadSummary: "membership_id=\(membershipId.uuidString), status=active"
            )
        ) as [BackendHouseholdMembership]
        guard let first = updated.first else {
            throw ServiceError.requestFailed("Failed to approve membership.")
        }
#if DEBUG
        print("[HouseholdBackendService] membership approval result membership_id=\(membershipId.uuidString), status=\(first.status ?? "nil")")
#endif
        return first
    }

    func approveMembershipRequest(membershipId: UUID, session: AuthUserSession) async throws {
        let membership = try await fetchMembershipById(membershipId: membershipId, session: session)
        try await requireOrganiserPermission(
            householdId: membership.householdId,
            session: session,
            action: "approveMembershipRequest"
        )
        _ = try await updateMembershipRequestStatus(
            membershipId: membershipId,
            status: "active",
            operation: "approveMembershipRequest",
            session: session
        )
    }

    func rejectMembershipRequest(membershipId: UUID, session: AuthUserSession) async throws {
        let membership = try await fetchMembershipById(membershipId: membershipId, session: session)
        try await requireOrganiserPermission(
            householdId: membership.householdId,
            session: session,
            action: "rejectMembershipRequest"
        )
        _ = try await updateMembershipRequestStatus(
            membershipId: membershipId,
            status: "rejected",
            operation: "rejectMembershipRequest",
            session: session
        )
    }

    func updateMembershipAccess(
        membershipId: UUID,
        accessRole: String,
        relationshipLabel: String?,
        session: AuthUserSession
    ) async throws -> BackendHouseholdMembership {
        let membership = try await fetchMembershipById(membershipId: membershipId, session: session)
        try await requireOrganiserPermission(
            householdId: membership.householdId,
            session: session,
            action: "updateMembershipAccess"
        )
        guard let normalizedRole = normalizeAccessRole(accessRole) else {
            throw ServiceError.requestFailed("Invalid access role.")
        }
        let payload = UpdateMembershipAccessRequest(
            access_role: normalizedRole,
            relationship_label: normalizeRelationshipLabel(relationshipLabel),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        let rows = try await patch(
            path: "household_memberships?id=eq.\(membershipId.uuidString)",
            payload: payload,
            session: session,
            context: WriteDiagnosticContext(
                operation: "updateMembershipAccess",
                tableOrEndpoint: "household_memberships",
                payloadSummary: "membership_id=\(membershipId.uuidString), access_role=\(normalizedRole)"
            )
        ) as [BackendHouseholdMembership]
        guard let first = rows.first else {
            throw ServiceError.requestFailed("Failed to update membership access.")
        }
        return first
    }

    func removeHouseholdMember(
        membershipId: UUID,
        session: AuthUserSession
    ) async throws -> BackendHouseholdMembership {
        let membership = try await fetchMembershipById(membershipId: membershipId, session: session)
        try await requireOrganiserPermission(
            householdId: membership.householdId,
            session: session,
            action: "removeHouseholdMember"
        )
        let members = try await fetchHouseholdMembers(householdId: membership.householdId, session: session)
        let activeMembers = members.filter(\.isActive)
        let evaluation = HouseholdMemberRemovalPolicy.evaluate(
            membership: membership,
            activeMembers: activeMembers
        )
        guard evaluation.canRemove else {
            throw ServiceError.cannotRemoveMember(
                evaluation.blockedReason ?? "This member cannot be removed."
            )
        }
        return try await updateMembershipAttributes(
            membershipId: membershipId,
            role: nil,
            status: HouseholdMembershipStatus.revoked.rawValue,
            familyRole: nil,
            relationshipLabel: nil,
            session: session
        )
    }

    func resolveHouseholdByJoinCode(prefix: String, session: AuthUserSession) async throws -> [BackendHousehold] {
#if DEBUG
        print("[HouseholdBackendService] RPC JOIN RESOLVE PREFIX=\(prefix)")
#endif
        let url = try SupabaseClientProvider.restURL(path: "rpc/resolve_household_by_join_code")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try authenticatedHeaders(
            session: session,
            request: request,
            operation: "resolveHouseholdByJoinCode",
            tableOrEndpoint: "rpc/resolve_household_by_join_code",
            payloadSummary: "code_prefix=\(prefix)"
        )
        request.httpBody = try JSONEncoder().encode(ResolveByJoinCodeRPCPayload(code_prefix: prefix))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed("Invalid backend response.")
        }
        let text = String(data: data, encoding: .utf8) ?? ""
#if DEBUG
        print("[HouseholdBackendService] RPC JOIN RESOLVE STATUS=\(http.statusCode)")
        print("[HouseholdBackendService] RPC JOIN RESOLVE RAW=\(text)")
#endif
        guard (200..<300).contains(http.statusCode) else {
            throw ServiceError.requestFailed(
                BackendWriteDiagnostics.describeBackendFailure(
                    operation: "resolveHouseholdByJoinCode",
                    tableOrEndpoint: "rpc/resolve_household_by_join_code",
                    statusCode: http.statusCode,
                    responseBody: text.isEmpty ? "Unknown backend error." : text
                )
            )
        }
        let decoder = JSONDecoder()
        let matches = try decoder.decode([BackendHousehold].self, from: data)
#if DEBUG
        print("[HouseholdBackendService] RPC JOIN RESOLVE MATCH COUNT=\(matches.count)")
#endif
        return matches
    }

    func fetchInvitePreviewByCode(_ code: String, session: AuthUserSession?) async throws -> HouseholdInvitePreview? {
        guard BackendConfig.isSupabaseConfigured else {
            throw ServiceError.backendNotConfigured
        }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return nil }
        guard let session else {
#if DEBUG
            print("[HouseholdBackendService] invite lookup by code skipped (no auth session) code=\(trimmed)")
#endif
            return nil
        }
#if DEBUG
        print(
            "[HouseholdBackendService] invite lookup by code (REST) code=\(trimmed) " +
            "auth_email=\(session.email ?? "nil")"
        )
#endif
        guard let invite = try await fetchInviteRowByInviteCode(trimmed, session: session) else {
            InviteFlowLogger.previewRPCCompleted(
                function: "household_invites_by_code",
                authUserId: session.userId,
                rowCount: 0,
                preview: nil
            )
            return nil
        }
        let preview = try await buildHouseholdInvitePreview(from: invite, session: session)
        InviteFlowLogger.previewRPCCompleted(
            function: "household_invites_by_code",
            authUserId: session.userId,
            rowCount: preview == nil ? 0 : 1,
            preview: preview
        )
        return preview
    }

    func fetchInvitePreviewByToken(_ token: String, session: AuthUserSession?) async throws -> HouseholdInvitePreview? {
        guard BackendConfig.isSupabaseConfigured else {
            throw ServiceError.backendNotConfigured
        }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        guard let session else {
#if DEBUG
            print("[HouseholdBackendService] invite lookup by token skipped (no auth session)")
#endif
            return nil
        }
#if DEBUG
        print("[HouseholdBackendService] invite lookup by token (REST) auth_email=\(session.email ?? "nil")")
#endif
        guard let invite = try await fetchInviteRowByInviteToken(trimmed, session: session) else {
            InviteFlowLogger.previewRPCCompleted(
                function: "household_invites_by_token",
                authUserId: session.userId,
                rowCount: 0,
                preview: nil
            )
            return nil
        }
        let preview = try await buildHouseholdInvitePreview(from: invite, session: session)
        InviteFlowLogger.previewRPCCompleted(
            function: "household_invites_by_token",
            authUserId: session.userId,
            rowCount: preview == nil ? 0 : 1,
            preview: preview
        )
        return preview
    }

    func acceptHouseholdInviteRPC(inviteCode: String, session: AuthUserSession) async throws -> HouseholdInviteAcceptRPCResponse {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
#if DEBUG
        print("[HouseholdBackendService] RPC accept_household_invite p_code=\(trimmed)")
#endif
        let response: HouseholdInviteAcceptRPCResponse = try await postInviteRPCValue(
            function: "accept_household_invite",
            body: AcceptInviteByCodeRPCRequest(p_code: trimmed),
            session: session
        )
        InviteFlowLogger.rpcInviteCompleted(
            function: "accept_household_invite",
            outcome: response.outcome,
            householdId: response.householdId,
            authUserId: session.userId
        )
        return response
    }

    func acceptHouseholdInviteRPC(inviteToken: String, session: AuthUserSession) async throws -> HouseholdInviteAcceptRPCResponse {
        let trimmed = inviteToken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
#if DEBUG
        print("[HouseholdBackendService] RPC accept_household_invite_by_token")
#endif
        let response: HouseholdInviteAcceptRPCResponse = try await postInviteRPCValue(
            function: "accept_household_invite_by_token",
            body: AcceptInviteByTokenRPCRequest(p_token: trimmed),
            session: session
        )
        InviteFlowLogger.rpcInviteCompleted(
            function: "accept_household_invite_by_token",
            outcome: response.outcome,
            householdId: response.householdId,
            authUserId: session.userId
        )
        return response
    }

    func declineHouseholdInviteRPC(inviteCode: String, session: AuthUserSession) async throws -> HouseholdInviteAcceptRPCResponse {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
#if DEBUG
        print("[HouseholdBackendService] RPC decline_household_invite p_code=\(trimmed)")
#endif
        let response: HouseholdInviteAcceptRPCResponse = try await postInviteRPCValue(
            function: "decline_household_invite",
            body: DeclineInviteRPCRequest(p_code: trimmed),
            session: session
        )
        InviteFlowLogger.rpcInviteCompleted(
            function: "decline_household_invite",
            outcome: response.outcome,
            householdId: response.householdId,
            authUserId: session.userId
        )
        return response
    }

    func acceptHouseholdInviteRPC(inviteId: UUID, session: AuthUserSession) async throws -> HouseholdInviteAcceptRPCResponse {
#if DEBUG
        print("[HouseholdBackendService] RPC accept_household_invite_by_id invite_id=\(inviteId.uuidString)")
#endif
        let response: HouseholdInviteAcceptRPCResponse = try await postInviteRPCValue(
            function: "accept_household_invite_by_id",
            body: AcceptInviteByIdRPCRequest(p_invite_id: inviteId),
            session: session
        )
        InviteFlowLogger.rpcInviteCompleted(
            function: "accept_household_invite_by_id",
            outcome: response.outcome,
            householdId: response.householdId,
            authUserId: session.userId
        )
        return response
    }

    func fetchInvitePreviewByInviteId(_ inviteId: UUID, session: AuthUserSession?) async throws -> HouseholdInvitePreview? {
        guard BackendConfig.isSupabaseConfigured else {
            throw ServiceError.backendNotConfigured
        }
        guard let session else { return nil }
#if DEBUG
        print("[HouseholdBackendService] invite lookup by id (RPC) invite_id=\(inviteId.uuidString)")
#endif
        let rows: [HouseholdInvitePreview] = try await postInviteRPCCollection(
            function: "get_invite_by_id",
            body: GetInviteByIdRPCRequest(p_invite_id: inviteId),
            session: session
        )
        let preview = rows.first
        InviteFlowLogger.previewRPCCompleted(
            function: "get_invite_by_id",
            authUserId: session.userId,
            rowCount: preview == nil ? 0 : 1,
            preview: preview
        )
        return preview
    }

    func joinHouseholdByCode(_ code: String, session: AuthUserSession) async throws -> BackendHousehold {
        guard let userId = UUID(uuidString: session.userId) else {
            throw ServiceError.invalidUserId
        }
#if DEBUG
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        print("[HouseholdBackendService] JOIN CODE RECEIVED=\(normalized)")
#endif
        if parseHouseholdJoinCode(code) == nil {
            return try await joinHouseholdByInviteCode(code, session: session)
        }
        guard let prefix = parseHouseholdJoinCode(code) else {
#if DEBUG
            print("[HouseholdBackendService] JOIN CODE PARSE FAILED")
#endif
            throw ServiceError.invalidJoinCodeFormat
        }
#if DEBUG
        print("[HouseholdBackendService] JOIN CODE PREFIX=\(prefix)")
#endif

        let matches = try await resolveHouseholdByJoinCode(prefix: prefix, session: session)
#if DEBUG
        print("[HouseholdBackendService] RPC JOIN RESOLVE MATCH COUNT=\(matches.count)")
#endif
        guard !matches.isEmpty else {
            throw ServiceError.joinCodeNotFound
        }
        guard matches.count == 1, let matched = matches.first else {
#if DEBUG
            let ids = matches.map(\.id.uuidString).joined(separator: ",")
            print("[HouseholdBackendService] ambiguous matches for prefix=\(prefix), ids=\(ids)")
#endif
            throw ServiceError.joinCodeAmbiguous
        }
#if DEBUG
        print("[HouseholdBackendService] JOIN HOUSEHOLD MATCH ID=\(matched.id.uuidString) NAME=\(matched.name)")
#endif

        let currentMemberships = try await fetchMyMemberships(session: session)
        if currentMemberships.contains(where: { $0.householdId == matched.id && $0.userId == userId }) {
#if DEBUG
            print("[HouseholdBackendService] JOIN HOUSEHOLD ALREADY MEMBER household_id=\(matched.id.uuidString)")
#endif
            throw ServiceError.alreadyMember
        }
        try await createPendingObserverMembership(
            householdId: matched.id,
            userId: userId,
            session: session,
            operation: "joinHouseholdByCode"
        )
#if DEBUG
        print(
            "[HouseholdBackendService] join-by-code membership created pending " +
            "household_id=\(matched.id.uuidString) user_id=\(userId.uuidString) access_role=observer"
        )
        print("[HouseholdBackendService] JOIN HOUSEHOLD SUCCESS household_id=\(matched.id.uuidString)")
#endif
        return matched
    }

    func joinHouseholdByInviteCode(_ code: String, session: AuthUserSession) async throws -> BackendHousehold {
        guard let userId = UUID(uuidString: session.userId) else {
            throw ServiceError.invalidUserId
        }
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else {
            throw ServiceError.invalidJoinCodeFormat
        }
#if DEBUG
        print("[HouseholdBackendService] join-by-invite-code invite_code=\(normalizedCode) user_id=\(userId.uuidString)")
#endif
        if let preview = try await fetchInvitePreviewByCode(normalizedCode, session: session), preview.isPendingAndNotExpired {
#if DEBUG
            print("[HouseholdBackendService] join-by-invite-code matched pending invite household_id=\(preview.householdId.uuidString)")
#endif
            let accept = try await acceptHouseholdInviteRPC(inviteCode: normalizedCode, session: session)
#if DEBUG
            print("[HouseholdBackendService] join-by-invite-code rpc outcome=\(accept.outcome) household_id=\(accept.householdId?.uuidString ?? "nil")")
#endif
            switch accept.outcome.lowercased() {
            case "joined", "already_member":
                guard let householdId = accept.householdId else {
                    throw ServiceError.requestFailed("Something went wrong while joining the household. Please try again.")
                }
                return try await fetchHouseholdById(householdId, session: session)
            default:
                throw Self.serviceErrorFromAcceptOutcome(accept.outcome)
            }
        }

        if let preview = try await fetchInvitePreviewByCode(normalizedCode, session: session) {
            try Self.throwUnavailablePreview(preview)
        }

        let household = try await fetchHouseholdByInviteCode(normalizedCode, session: session)
#if DEBUG
        print("[HouseholdBackendService] join-by-invite-code public household invite_code household_id=\(household.id.uuidString)")
#endif
        let currentMemberships = try await fetchMyMemberships(session: session)
        if currentMemberships.contains(where: { $0.householdId == household.id && $0.userId == userId }) {
            throw ServiceError.alreadyMember
        }
        try await createPendingObserverMembership(
            householdId: household.id,
            userId: userId,
            session: session,
            operation: "joinHouseholdByInviteCode"
        )
#if DEBUG
        print("[HouseholdBackendService] join-by-invite-code pending observer membership created")
#endif
        return household
    }

    func fetchHouseholdByInviteCode(_ code: String, session: AuthUserSession) async throws -> BackendHousehold {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else {
            throw ServiceError.invalidJoinCodeFormat
        }
        let path = "households?select=*&invite_code=eq.\(encodeQueryValue(normalizedCode))&limit=1"
        let matches: [BackendHousehold] = try await get(path: path, session: session)
        guard let household = matches.first else {
            throw ServiceError.joinCodeNotFound
        }
        return household
    }

    func inspectJoinByInviteCode(_ code: String, session: AuthUserSession?) async throws -> InviteCodeJoinResult {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else {
            throw ServiceError.invalidJoinCodeFormat
        }
#if DEBUG
        print("[HouseholdBackendService] inspectJoinByInviteCode lookup=rest_invite_code auth=\(session != nil) code=\(normalizedCode)")
#endif
        if let preview = try await fetchInvitePreviewByCode(normalizedCode, session: session) {
            if preview.isPendingAndNotExpired {
                return .matchedInvite(preview.asSyntheticHousehold())
            }
            try Self.throwUnavailablePreview(preview)
        }
        guard let session else {
            throw ServiceError.inviteNotFound
        }
        let household = try await fetchHouseholdByInviteCode(normalizedCode, session: session)
        return .noInviteExists(household)
    }

    func hasPendingInviteForSignedInUser(householdId: UUID, session: AuthUserSession) async throws -> Bool {
        let invite = try await pendingInviteForSignedInUser(householdId: householdId, session: session)
        return invite != nil
    }

    func fetchHouseholdMembers(householdId: UUID, session: AuthUserSession) async throws -> [BackendHouseholdMembership] {
        let path = "household_memberships?select=*&household_id=eq.\(householdId.uuidString)&order=created_at.asc"
        let members: [BackendHouseholdMembership] = try await get(path: path, session: session)
#if DEBUG
        let userIds = members.map { $0.userId.uuidString }.joined(separator: ",")
        print(
            "[HouseholdBackendService] activeHouseholdId=\(householdId.uuidString), " +
            "fetched_membership_count=\(members.count), fetched_membership_user_ids=[\(userIds)]"
        )
#endif
        return members
    }

    func updateMembershipAttributes(
        membershipId: UUID,
        role: String?,
        status: String?,
        familyRole: String?,
        relationshipLabel: String?,
        session: AuthUserSession
    ) async throws -> BackendHouseholdMembership {
        let membership = try await fetchMembershipById(membershipId: membershipId, session: session)
        try await requireOrganiserPermission(
            householdId: membership.householdId,
            session: session,
            action: "updateMembershipAttributes"
        )
        let roleCopy = role.map { String($0) }
        let statusCopy = status.map { String($0) }
        let familyRoleCopy = familyRole.map { String($0) }
        let relationshipLabelCopy = relationshipLabel.map { String($0) }
#if DEBUG
        print("[Backend] updateMembershipAttributes roleCopy=\(roleCopy ?? "nil")")
#endif

        let normalizedRole: String?
        let trimmedRole: String? = {
            guard let role = roleCopy else { return nil }
            let trimmed = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return trimmed.isEmpty ? nil : trimmed
        }()
        if let trimmedRole, !trimmedRole.isEmpty {
            normalizedRole = (trimmedRole == "admin" || trimmedRole == "member") ? trimmedRole : nil
        } else {
            normalizedRole = nil
        }
        let normalizedStatus: String?
        let trimmedStatus: String? = {
            guard let status = statusCopy else { return nil }
            let trimmed = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return trimmed.isEmpty ? nil : trimmed
        }()
        if let trimmedStatus, !trimmedStatus.isEmpty {
            normalizedStatus = HouseholdMembershipStatus(rawValue: trimmedStatus)?.rawValue
        } else {
            normalizedStatus = nil
        }
        let normalizedFamilyRole: String? = {
            guard let familyRole = familyRoleCopy else { return nil }
            let trimmed = familyRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return trimmed.isEmpty ? nil : trimmed
        }()
        let allowedFamilyRoles = Set(["parent", "driver", "helper", "guardian", "observer"])
        let safeFamilyRole = normalizedFamilyRole.flatMap { normalized in
            allowedFamilyRoles.contains(normalized) ? normalized : nil
        }
        let safeRelationshipLabel: String? = {
            guard let relationshipLabel = relationshipLabelCopy else { return nil }
            let trimmed = relationshipLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return trimmed
        }()

        let payload = UpdateMembershipAttributesRequest(
            role: normalizedRole,
            status: normalizedStatus,
            family_role: safeFamilyRole,
            relationship_label: safeRelationshipLabel
        )

        let rows: [BackendHouseholdMembership] = try await patch(
            path: "household_memberships?id=eq.\(membershipId.uuidString)",
            payload: payload,
            session: session,
            context: WriteDiagnosticContext(
                operation: "updateMembershipAttributes",
                tableOrEndpoint: "household_memberships",
                payloadSummary: "membership_id=\(membershipId.uuidString), role=\(payload.role ?? "nil"), status=\(payload.status ?? "nil"), family_role=\(payload.family_role ?? "nil"), relationship_label=\(payload.relationship_label ?? "nil")"
            )
        )
        guard let updated = rows.first else {
            throw MembershipError.notAuthorizedOrNotFound
        }
#if DEBUG
        print("[HouseholdBackendService] PATCH MEMBERSHIP DECODED id=\(updated.id.uuidString), role=\(updated.role), status=\(updated.status ?? "nil"), family_role=\(updated.familyRole ?? "nil"), relationship_label=\(updated.relationshipLabel ?? "nil")")
#endif
        return updated
    }

    private func rpcHeaders(session: AuthUserSession?) throws -> [String: String] {
        if let session {
            let trimmed = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return try SupabaseClientProvider.authenticatedHeaders(accessToken: trimmed)
            }
        }
        let config = try SupabaseClientProvider.configuration()
        return try SupabaseClientProvider.defaultHeaders(accessToken: config.anonKey)
    }

    private func inviteRPCRequest(function: String, body: some Encodable, session: AuthUserSession?) throws -> URLRequest {
        let url = try SupabaseClientProvider.restURL(path: "rpc/\(function)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try rpcHeaders(session: session)
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        return request
    }

    private func postInviteRPCCollection<T: Decodable, B: Encodable>(
        function: String,
        body: B,
        session: AuthUserSession?
    ) async throws -> T {
        let request = try inviteRPCRequest(function: function, body: body, session: session)
        return try await perform(request)
    }

    private func postInviteRPCValue<T: Decodable, B: Encodable>(
        function: String,
        body: B,
        session: AuthUserSession
    ) async throws -> T {
        let initialSession = try await validatedSessionForWrite(
            session,
            operation: function,
            forceRefresh: false
        )
        let request = try inviteRPCRequest(function: function, body: body, session: initialSession)
        do {
            return try await perform(request)
        } catch let error as ServiceError where shouldRetryAfterUnauthorized(error) {
            let refreshedSession = try await validatedSessionForWrite(
                session,
                operation: function,
                forceRefresh: true
            )
            let retryRequest = try inviteRPCRequest(function: function, body: body, session: refreshedSession)
            return try await perform(retryRequest)
        } catch {
            throw mapSessionError(error)
        }
    }

    private static func serviceErrorFromAcceptOutcome(_ outcome: String) -> ServiceError {
        switch outcome.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "invalid_code":
            return .inviteNotFound
        case "expired":
            return .inviteExpired
        case "already_used":
            return .inviteAlreadyClaimed
        case "cancelled":
            return .inviteCancelled
        case "declined":
            return .inviteDeclined
        case "not_authenticated":
            return .sessionExpired
        default:
            return .requestFailed("Something went wrong while joining the household. Please try again.")
        }
    }

    private static func throwUnavailablePreview(_ preview: HouseholdInvitePreview) throws {
        switch preview.normalizedInviteStatus {
        case .cancelled:
            throw ServiceError.inviteCancelled
        case .accepted:
            throw ServiceError.inviteAlreadyClaimed
        case .declined:
            throw ServiceError.inviteDeclined
        case .expired:
            throw ServiceError.inviteExpired
        case .pending:
            if let expiresAt = preview.expiresAt,
               let parsed = BackendTimestampParser.parse(expiresAt),
               parsed < Date() {
                throw ServiceError.inviteExpired
            }
            throw ServiceError.inviteNotFound
        case .none:
            throw ServiceError.inviteNotFound
        }
    }

    private func get<T: Decodable>(path: String, session: AuthUserSession) async throws -> T {
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = try authenticatedHeaders(
            session: session,
            request: request,
            operation: "fetchHouseholds",
            tableOrEndpoint: path
        )
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        return try await perform(request)
    }

    private func post<T: Decodable, P: Encodable>(
        table: String,
        payload: P,
        session: AuthUserSession,
        context: WriteDiagnosticContext? = nil
    ) async throws -> T {
        let operation = context?.operation ?? "write"
        let endpoint = context?.tableOrEndpoint ?? table
        let summary = context?.payloadSummary ?? "n/a"
        let initialSession = try await validatedSessionForWrite(
            session,
            operation: operation,
            forceRefresh: false
        )
        let encodedPayload = try JSONEncoder().encode(payload)

        do {
            return try await executeWriteRequest(
                method: "POST",
                path: table,
                payload: encodedPayload,
                session: initialSession,
                operation: operation,
                tableOrEndpoint: endpoint,
                payloadSummary: summary,
                writeContext: context
            )
        } catch let error as ServiceError where shouldRetryAfterUnauthorized(error) {
            let refreshedSession = try await validatedSessionForWrite(
                session,
                operation: operation,
                forceRefresh: true
            )
            do {
                let retried: T = try await executeWriteRequest(
                    method: "POST",
                    path: table,
                    payload: encodedPayload,
                    session: refreshedSession,
                    operation: operation,
                    tableOrEndpoint: endpoint,
                    payloadSummary: summary,
                    writeContext: context
                )
#if DEBUG
                print("[Auth] \(operation) session valid=false refresh_attempted=true retry=true success=true")
#endif
                return retried
            } catch {
#if DEBUG
                print("[Auth] \(operation) session valid=false refresh_attempted=true retry=true success=false")
#endif
                throw mapSessionError(error)
            }
        } catch {
            throw mapSessionError(error)
        }
    }

    private func patch<T: Decodable, P: Encodable>(
        path: String,
        payload: P,
        session: AuthUserSession,
        context: WriteDiagnosticContext? = nil
    ) async throws -> T {
        let operation = context?.operation ?? "write"
        let endpoint = context?.tableOrEndpoint ?? path
        let summary = context?.payloadSummary ?? "n/a"
        let initialSession = try await validatedSessionForWrite(
            session,
            operation: operation,
            forceRefresh: false
        )
        let encodedPayload = try JSONEncoder().encode(payload)

        do {
            return try await executeWriteRequest(
                method: "PATCH",
                path: path,
                payload: encodedPayload,
                session: initialSession,
                operation: operation,
                tableOrEndpoint: endpoint,
                payloadSummary: summary,
                writeContext: context
            )
        } catch let error as ServiceError where shouldRetryAfterUnauthorized(error) {
            let refreshedSession = try await validatedSessionForWrite(
                session,
                operation: operation,
                forceRefresh: true
            )
            do {
                let retried: T = try await executeWriteRequest(
                    method: "PATCH",
                    path: path,
                    payload: encodedPayload,
                    session: refreshedSession,
                    operation: operation,
                    tableOrEndpoint: endpoint,
                    payloadSummary: summary,
                    writeContext: context
                )
#if DEBUG
                print("[Auth] \(operation) session valid=false refresh_attempted=true retry=true success=true")
#endif
                return retried
            } catch {
#if DEBUG
                print("[Auth] \(operation) session valid=false refresh_attempted=true retry=true success=false")
#endif
                throw mapSessionError(error)
            }
        } catch {
            throw mapSessionError(error)
        }
    }

    private func executeWriteRequest<T: Decodable>(
        method: String,
        path: String,
        payload: Data,
        session: AuthUserSession,
        operation: String,
        tableOrEndpoint: String,
        payloadSummary: String,
        writeContext: WriteDiagnosticContext?
    ) async throws -> T {
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = try authenticatedHeaders(
            session: session,
            request: request,
            operation: operation,
            tableOrEndpoint: tableOrEndpoint,
            payloadSummary: payloadSummary
        )
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = payload
        return try await perform(request, writeContext: writeContext)
    }

    private func sendInviteEmailAfterCreation(
        invite: BackendHouseholdInvite,
        accessRole: String,
        relationship: String?,
        session: AuthUserSession
    ) async {
        do {
            let inviteContext = await fetchInviteEmailContext(householdId: invite.householdId, session: session)
            let tribeName: String = {
                let trimmed = inviteContext?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? "TribeBoard" : trimmed
            }()
            let inviteCode = invite.inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                ?? inviteContext?.inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                ?? "UNKNOWN"
            try await sendInviteEmailRequest(
                invite: invite,
                tribeName: tribeName,
                inviteCode: inviteCode,
                accessRole: accessRole,
                relationship: relationship,
                session: session,
                logPrefix: "sendInviteEmail"
            )
#if DEBUG
            print("[Invite] email_sent success=true email=\(invite.email)")
#endif
        } catch {
            InviteFlowLogger.inviteEmailHTTPResult(
                inviteId: invite.id,
                householdId: invite.householdId,
                invitedEmail: invite.email,
                authUserId: session.userId,
                success: false,
                statusCode: nil,
                logPrefix: "sendInviteEmail"
            )
#if DEBUG
            print("[Invite] email_sent success=false email=\(invite.email) error=\(error.localizedDescription)")
#endif
        }
    }

    private func sendInviteEmailRequest(
        invite: BackendHouseholdInvite,
        tribeName: String,
        inviteCode: String,
        accessRole: String,
        relationship: String?,
        session: AuthUserSession,
        logPrefix: String
    ) async throws {
        let url = URL(string: "https://bxiyosyhkbyvnbqgictr.functions.supabase.co/sendInviteEmail")
        guard let url else {
            throw ServiceError.requestFailed("Invalid sendInviteEmail URL.")
        }
        let anonKey = BackendConfig.supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !anonKey.isEmpty else {
            throw ServiceError.requestFailed("Missing SUPABASE_ANON_KEY for sendInviteEmail.")
        }
        let inviteURL = InviteLinkBuilder.webURL(for: invite)
        let inviterLabel: String? = {
            if let name = session.providerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                return name
            }
            if let email = session.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
                return email
            }
            return nil
        }()
        let payload = SendInviteEmailRequest(
            email: invite.email,
            household_id: invite.householdId.uuidString.lowercased(),
            invite_id: invite.id.uuidString.lowercased(),
            tribe_name: tribeName,
            invite_code: inviteCode,
            invite_token: invite.inviteToken?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            access_role: accessRole,
            relationship: relationship ?? "",
            invite_url: inviteURL,
            inviter_display_name: inviterLabel
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
            "Content-Type": "application/json",
            "apikey": anonKey,
            "Authorization": "Bearer \(anonKey)"
        ]
        let payloadData = try JSONEncoder().encode(payload)
        request.httpBody = payloadData
#if DEBUG
        let payloadJSON = String(data: payloadData, encoding: .utf8) ?? "{}"
        let sanitizedHeaders: [String: String] = [
            "Content-Type": "application/json",
            "apikey": "\(String(anonKey.prefix(6)))...",
            "Authorization": "Bearer \(String(anonKey.prefix(6)))..."
        ]
        print("[Invite] invite_code_used=\(inviteCode)")
        print("[Invite] invite_url=\(inviteURL)")
        print("[Invite] \(logPrefix) request_url=\(url.absoluteString)")
        print("[Invite] \(logPrefix) headers=\(sanitizedHeaders)")
        print("[Invite] \(logPrefix) payload=\(payloadJSON)")
#endif
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed("Invalid email function response.")
        }
        let body = String(data: data, encoding: .utf8) ?? ""
#if DEBUG
        print("[Invite] \(logPrefix) response_status=\(http.statusCode)")
        print("[Invite] \(logPrefix) response_body=\(body)")
#endif
        guard (200..<300).contains(http.statusCode) else {
            InviteFlowLogger.inviteEmailHTTPResult(
                inviteId: invite.id,
                householdId: invite.householdId,
                invitedEmail: invite.email,
                authUserId: session.userId,
                success: false,
                statusCode: http.statusCode,
                logPrefix: logPrefix
            )
            throw ServiceError.requestFailed("sendInviteEmail failed (\(http.statusCode)): \(body)")
        }
        InviteFlowLogger.inviteEmailHTTPResult(
            inviteId: invite.id,
            householdId: invite.householdId,
            invitedEmail: invite.email,
            authUserId: session.userId,
            success: true,
            statusCode: http.statusCode,
            logPrefix: logPrefix
        )
    }

    private func fetchInviteEmailContext(
        householdId: UUID,
        session: AuthUserSession
    ) async -> HouseholdInviteEmailContextResponse? {
        do {
            let path = "households?select=name,invite_code&id=eq.\(householdId.uuidString.lowercased())&limit=1"
            let rows: [HouseholdInviteEmailContextResponse] = try await get(path: path, session: session)
            return rows.first
        } catch {
#if DEBUG
            print("[Invite] sendInviteEmail context_lookup_failed household_id=\(householdId.uuidString) error=\(error.localizedDescription)")
#endif
            return nil
        }
    }

    private func validatedSessionForWrite(
        _ session: AuthUserSession,
        operation: String,
        forceRefresh: Bool
    ) async throws -> AuthUserSession {
        let restoredSession = try await authService.restoreSession()
        let activeSession = restoredSession ?? session
        let hasAccessToken = !activeSession.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isExpired = (activeSession.expiresAt?.timeIntervalSinceNow ?? .infinity) <= 30
        let requiresRefresh = forceRefresh || !hasAccessToken || isExpired
#if DEBUG
        print("[Auth] \(operation) session_exists=\(restoredSession != nil)")
#endif
        guard requiresRefresh else {
#if DEBUG
            print("[Auth] \(operation) session valid=true refresh_attempted=false retry=false success=true")
#endif
            return activeSession
        }

        let refreshed = try await refreshSessionForWrite(from: activeSession, operation: operation)
        guard let refreshed else {
#if DEBUG
            print("[Auth] \(operation) session valid=false refresh_attempted=true retry=false success=false fallback_sign_in=true")
#endif
            throw ServiceError.sessionExpired
        }
#if DEBUG
        print("[Auth] \(operation) session valid=false refresh_attempted=true retry=false success=true")
#endif
        return refreshed
    }

    private func refreshSessionForWrite(
        from session: AuthUserSession,
        operation: String
    ) async throws -> AuthUserSession? {
        guard let refreshToken = session.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !refreshToken.isEmpty else {
#if DEBUG
            print("[Auth] \(operation) refresh skipped: missing refresh token")
#endif
            return nil
        }

        let url = try SupabaseClientProvider.authURL(
            path: "token",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")]
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders()
        request.httpBody = try JSONEncoder().encode([
            "refresh_token": refreshToken
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed("Invalid backend response.")
        }
        let raw = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
#if DEBUG
            print("[Auth] \(operation) refresh failed status=\(http.statusCode) body=\(raw)")
#endif
            if isSessionExpiredStatus(statusCode: http.statusCode, responseBody: raw) {
                return nil
            }
            throw ServiceError.requestFailed(
                BackendWriteDiagnostics.describeBackendFailure(
                    operation: "refreshSessionForWrite",
                    tableOrEndpoint: "auth/token?grant_type=refresh_token",
                    statusCode: http.statusCode,
                    responseBody: raw.isEmpty ? "Unknown backend error." : raw
                )
            )
        }

        let tokenResponse = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
        guard let accessToken = tokenResponse.access_token?.trimmingCharacters(in: .whitespacesAndNewlines),
              !accessToken.isEmpty else {
            return nil
        }
        let expiresAt = tokenResponse.expires_in.map { Date().addingTimeInterval(TimeInterval($0)) }
        let refreshed = AuthUserSession(
            accessToken: accessToken,
            refreshToken: tokenResponse.refresh_token ?? session.refreshToken,
            userId: tokenResponse.user?.id ?? session.userId,
            email: tokenResponse.user?.email ?? session.email,
            expiresAt: expiresAt ?? session.expiresAt,
            authProvider: session.authProvider,
            providerDisplayName: session.providerDisplayName
        )
        return refreshed
    }

    private func shouldRetryAfterUnauthorized(_ error: ServiceError) -> Bool {
        switch error {
        case .sessionExpired:
            return true
        case .requestFailed(let message):
            return isSessionExpiredMessage(message)
        default:
            return false
        }
    }

    private func mapSessionError(_ error: Error) -> Error {
        if let serviceError = error as? ServiceError {
            switch serviceError {
            case .sessionExpired:
                return ServiceError.sessionExpired
            case .requestFailed(let message) where isSessionExpiredMessage(message):
                return ServiceError.sessionExpired
            default:
                return serviceError
            }
        }
        if isSessionExpiredMessage(error.localizedDescription) {
            return ServiceError.sessionExpired
        }
        return error
    }

    private func isSessionExpiredStatus(statusCode: Int, responseBody: String) -> Bool {
        statusCode == 401 || isSessionExpiredMessage(responseBody)
    }

    private func isSessionExpiredMessage(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("jwt expired")
            || normalized.contains("pgrst303")
            || normalized.contains("unauthenticated")
            || normalized.contains("session expired")
    }

    private func authenticatedHeaders(
        session: AuthUserSession,
        request: URLRequest,
        operation: String,
        tableOrEndpoint: String,
        payloadSummary: String = "n/a"
    ) throws -> [String: String] {
        do {
            return try SupabaseClientProvider.authenticatedHeaders(accessToken: session.accessToken)
        } catch {
            BackendWriteDiagnostics.record(
                operation: operation,
                tableOrEndpoint: tableOrEndpoint,
                request: request,
                statusCode: nil,
                responseBody: "",
                payloadSummary: payloadSummary,
                errorSummary: error.localizedDescription
            )
            throw ServiceError.requestFailed(error.localizedDescription)
        }
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        writeContext: WriteDiagnosticContext? = nil
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            if let writeContext {
                BackendWriteDiagnostics.record(
                    operation: writeContext.operation,
                    tableOrEndpoint: writeContext.tableOrEndpoint,
                    request: request,
                    statusCode: nil,
                    responseBody: "Invalid backend response.",
                    payloadSummary: writeContext.payloadSummary,
                    errorSummary: "Invalid backend response."
                )
            }
            throw ServiceError.requestFailed("Invalid backend response.")
        }
        let text = String(data: data, encoding: .utf8) ?? ""
#if DEBUG
        print(
            "[HouseholdBackendService] HTTP status=\(http.statusCode), path=\(request.url?.absoluteString ?? "unknown"), " +
            "raw_response=\(text)"
        )
#endif
        if let writeContext {
            BackendWriteDiagnostics.record(
                operation: writeContext.operation,
                tableOrEndpoint: writeContext.tableOrEndpoint,
                request: request,
                statusCode: http.statusCode,
                responseBody: text,
                payloadSummary: writeContext.payloadSummary,
                errorSummary: (200..<300).contains(http.statusCode) ? nil : "HTTP \(http.statusCode)"
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            let context = writeContext ?? WriteDiagnosticContext(
                operation: request.httpMethod ?? "REQUEST",
                tableOrEndpoint: request.url?.lastPathComponent ?? "unknown",
                payloadSummary: "n/a"
            )
            if isSessionExpiredStatus(statusCode: http.statusCode, responseBody: text) {
                throw ServiceError.sessionExpired
            }
            throw ServiceError.requestFailed(
                BackendWriteDiagnostics.describeBackendFailure(
                    operation: context.operation,
                    tableOrEndpoint: context.tableOrEndpoint,
                    statusCode: http.statusCode,
                    responseBody: text.isEmpty ? "Unknown backend error." : text
                )
            )
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
#if DEBUG
            print(
                "[HouseholdBackendService] DECODE FAILED type=\(String(describing: T.self)), " +
                "error=\(error.localizedDescription), raw_payload=\(text)"
            )
#endif
            throw error
        }
    }

    private func createPendingObserverMembership(
        householdId: UUID,
        userId: UUID,
        session: AuthUserSession,
        operation: String
    ) async throws {
        _ = try await post(
            table: "household_memberships",
            payload: [CreateMembershipRequest(
                household_id: householdId,
                user_id: userId,
                role: "member",
                status: "pending",
                access_role: HouseholdAccessRole.observer.rawValue,
                family_role: nil,
                relationship_label: nil,
                invited_by_user_id: nil,
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date())
            )],
            session: session,
            context: WriteDiagnosticContext(
                operation: operation,
                tableOrEndpoint: "household_memberships",
                payloadSummary: "household_id=\(householdId.uuidString), user_id=\(userId.uuidString), role=member, status=pending, access_role=observer"
            )
        ) as [BackendHouseholdMembership]
    }

    private func updateMembershipRequestStatus(
        membershipId: UUID,
        status: String,
        operation: String,
        session: AuthUserSession
    ) async throws -> BackendHouseholdMembership {
#if DEBUG
        print("[HouseholdBackendService] \(operation) start membership_id=\(membershipId.uuidString), status=\(status)")
#endif
        let rows: [BackendHouseholdMembership] = try await patch(
            path: "household_memberships?id=eq.\(membershipId.uuidString.lowercased())",
            payload: UpdateMembershipStatusRequest(
                status: status,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ),
            session: session,
            context: WriteDiagnosticContext(
                operation: operation,
                tableOrEndpoint: "household_memberships",
                payloadSummary: "membership_id=\(membershipId.uuidString), status=\(status)"
            )
        )
        guard let updated = rows.first else {
            throw ServiceError.requestFailed("No membership row updated for \(operation).")
        }
#if DEBUG
        print("[HouseholdBackendService] \(operation) success membership_id=\(membershipId.uuidString), status=\(updated.status ?? "nil")")
#endif
        return updated
    }

    private func nextAvailableHouseholdInviteCode(session: AuthUserSession) async throws -> String {
        var attempts = 0
        while attempts < 12 {
            attempts += 1
            let code = generateHouseholdInviteCode(length: 8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            if try await !householdInviteCodeExists(code, session: session),
               try await !inviteRowCodeExists(code, session: session) {
                return code
            }
        }
        throw ServiceError.requestFailed("Unable to generate unique invite code. Please try again.")
    }

    private func householdInviteCodeExists(_ code: String, session: AuthUserSession) async throws -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let path = "households?select=id&invite_code=eq.\(encodeQueryValue(normalized))&limit=1"
        let rows: [HouseholdIdResponse] = try await get(path: path, session: session)
        return !rows.isEmpty
    }

    private func ensureInviteCode(for householdId: UUID, session: AuthUserSession) async throws -> String {
        var attempts = 0
        while attempts < 12 {
            attempts += 1
            let candidate = generateHouseholdInviteCode(length: 8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            if try await inviteRowCodeExists(candidate, session: session) {
                continue
            }
            do {
                _ = try await patch(
                    path: "households?id=eq.\(householdId.uuidString.lowercased())",
                    payload: UpdateHouseholdInviteCodeRequest(invite_code: candidate),
                    session: session,
                    context: WriteDiagnosticContext(
                        operation: "ensureInviteCode",
                        tableOrEndpoint: "households",
                        payloadSummary: "household_id=\(householdId.uuidString), invite_code=\(candidate)"
                    )
                ) as [BackendHousehold]
#if DEBUG
                print("[HouseholdBackendService] ensured household invite_code household_id=\(householdId.uuidString), invite_code=\(candidate)")
#endif
                return candidate
            } catch {
                let message = error.localizedDescription.lowercased()
                if message.contains("duplicate key")
                    || message.contains("unique constraint")
                    || message.contains("households_invite_code_key") {
                    continue
                }
                throw error
            }
        }
        throw ServiceError.requestFailed("Unable to ensure invite code for household.")
    }

    private func normalizeEmail(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizeAccessRole(_ raw: String) -> String? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let role = HouseholdAccessRole(rawValue: normalized) else {
            return nil
        }
        return role.rawValue
    }

    private func normalizeRelationshipLabel(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func encodeQueryValue(_ value: String) -> String {
        let disallowed = CharacterSet(charactersIn: ",&=?")
        let allowed = CharacterSet.urlQueryAllowed.subtracting(disallowed)
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func fetchProfileByEmail(_ email: String, session: AuthUserSession) async throws -> BackendProfile? {
        let path = "profiles?select=*&email=eq.\(encodeQueryValue(email))&limit=1"
        let profiles: [BackendProfile] = try await get(path: path, session: session)
        return profiles.first
    }

    private func fetchMembership(
        householdId: UUID,
        userId: UUID,
        session: AuthUserSession
    ) async throws -> BackendHouseholdMembership? {
        let path = "household_memberships?select=*&household_id=eq.\(householdId.uuidString)&user_id=eq.\(userId.uuidString)&limit=1"
        let memberships: [BackendHouseholdMembership] = try await get(path: path, session: session)
        return memberships.first
    }

    private func fetchMembershipById(
        membershipId: UUID,
        session: AuthUserSession
    ) async throws -> BackendHouseholdMembership {
        let path = "household_memberships?select=*&id=eq.\(membershipId.uuidString.lowercased())&limit=1"
        let memberships: [BackendHouseholdMembership] = try await get(path: path, session: session)
        guard let membership = memberships.first else {
            throw ServiceError.requestFailed("Membership not found.")
        }
        return membership
    }

    private func requireOrganiserPermission(
        householdId: UUID,
        session: AuthUserSession,
        action: String
    ) async throws {
        guard let userId = UUID(uuidString: session.userId) else {
            throw ServiceError.invalidUserId
        }
        let membership = try await fetchMembership(
            householdId: householdId,
            userId: userId,
            session: session
        )
        do {
            try BackendPermissionGuard.requireOrganiser(membership, action: action)
        } catch let error as BackendPermissionError {
            throw mapPermissionError(error)
        }
    }

    private func mapPermissionError(_ error: BackendPermissionError) -> ServiceError {
        switch error {
        case .missingActiveMembership(let action):
            return .permissionDenied(action: action, role: "none")
        case .permissionDenied(let action, let role):
            return .permissionDenied(action: action, role: role)
        }
    }

    private func fetchInviteRowByInviteCode(
        _ code: String,
        session: AuthUserSession
    ) async throws -> BackendHouseholdInvite? {
        let path =
            "household_invites?select=*&invite_code=eq.\(encodeQueryValue(code))&order=created_at.desc&limit=1"
        let invites: [BackendHouseholdInvite] = try await get(path: path, session: session)
        return invites.first
    }

    private func fetchInviteRowByInviteToken(
        _ token: String,
        session: AuthUserSession
    ) async throws -> BackendHouseholdInvite? {
        let path =
            "household_invites?select=*&invite_token=eq.\(encodeQueryValue(token))&order=created_at.desc&limit=1"
        let invites: [BackendHouseholdInvite] = try await get(path: path, session: session)
        return invites.first
    }

    private func buildHouseholdInvitePreview(
        from invite: BackendHouseholdInvite,
        session: AuthUserSession
    ) async throws -> HouseholdInvitePreview {
        let household = try await fetchHouseholdById(invite.householdId, session: session)
        var inviterDisplayName = "Someone"
        if let invitedBy = invite.invitedBy {
            let profilePath =
                "profiles?select=display_name,email,first_name,last_name&id=eq.\(invitedBy.uuidString.lowercased())&limit=1"
            let profiles: [BackendProfile] = try await get(path: profilePath, session: session)
            if let profile = profiles.first {
                inviterDisplayName = AuthBackedMemberDisplayResolver.resolveName(
                    profile: profile,
                    relationshipLabel: invite.relationship
                )
            }
        }
        let tokenUUID = invite.inviteToken.flatMap { UUID(uuidString: $0) }
        return HouseholdInvitePreview(
            inviteId: invite.id,
            householdId: invite.householdId,
            householdName: household.name,
            inviterDisplayName: inviterDisplayName,
            accessRole: invite.accessRole,
            relationship: invite.relationship,
            status: invite.status,
            expiresAt: invite.expiresAt,
            inviteToken: tokenUUID,
            backupInviteCode: invite.inviteCode
        )
    }

    private func fetchPendingInvite(
        householdId: UUID,
        email: String,
        session: AuthUserSession
    ) async throws -> BackendHouseholdInvite? {
        let path = "household_invites?select=*&household_id=eq.\(householdId.uuidString)&email=eq.\(encodeQueryValue(email))&status=eq.\(InviteStatus.pending.rawValue)&limit=1"
        let invites: [BackendHouseholdInvite] = try await get(path: path, session: session)
        return invites.first
    }

    private func pendingInviteForSignedInUser(
        householdId: UUID,
        session: AuthUserSession
    ) async throws -> BackendHouseholdInvite? {
        guard let email = try await resolveSignedInUserEmail(session: session), !email.isEmpty else {
            return nil
        }
        let path = "household_invites?select=*&household_id=eq.\(householdId.uuidString.lowercased())&email=eq.\(encodeQueryValue(email))&status=eq.\(InviteStatus.pending.rawValue)&order=created_at.desc&limit=1"
        let invites: [BackendHouseholdInvite] = try await get(path: path, session: session)
        return invites.first
    }

    private func fetchInviteById(
        inviteId: UUID,
        session: AuthUserSession
    ) async throws -> BackendHouseholdInvite? {
        if let preview = try? await fetchInvitePreviewByInviteId(inviteId, session: session) {
            let email = (try? await resolveSignedInUserEmail(session: session)) ?? ""
            return preview.toBackendInvite(email: email)
        }
        let path = "household_invites?select=*&id=eq.\(inviteId.uuidString.lowercased())&limit=1"
        let invites: [BackendHouseholdInvite] = try await get(path: path, session: session)
        return invites.first
    }

    private func fetchPendingInvitesViaRPC(
        session: AuthUserSession,
        email: String
    ) async throws -> [BackendHouseholdInvite] {
        let previews: [HouseholdInvitePreview] = try await postInviteRPCCollection(
            function: "list_pending_invites_for_current_user",
            body: EmptyRPCBody(),
            session: session
        )
        return previews
            .filter { $0.normalizedInviteStatus == .pending && $0.isPendingAndNotExpired }
            .map { $0.toBackendInvite(email: email) }
    }

    private func acceptPendingInviteViaRPC(
        invite: BackendHouseholdInvite,
        session: AuthUserSession
    ) async throws -> HouseholdInviteAcceptRPCResponse {
        if let code = invite.inviteCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
           !code.isEmpty {
            return try await acceptHouseholdInviteRPC(inviteCode: code, session: session)
        }
        if let token = invite.inviteToken?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !token.isEmpty {
            return try await acceptHouseholdInviteRPC(inviteToken: token, session: session)
        }
        return try await acceptHouseholdInviteRPC(inviteId: invite.id, session: session)
    }

    private func acceptPendingInvitesViaREST(
        pendingInvites: [BackendHouseholdInvite],
        session: AuthUserSession
    ) async throws {
        guard let userId = UUID(uuidString: session.userId) else {
            throw ServiceError.invalidUserId
        }
        let now = ISO8601DateFormatter().string(from: Date())
        for invite in pendingInvites {
            let existingMembership = try await fetchMembership(
                householdId: invite.householdId,
                userId: userId,
                session: session
            )
            if existingMembership == nil {
                _ = try await post(
                    table: "household_memberships",
                    payload: [CreateMembershipRequest(
                        household_id: invite.householdId,
                        user_id: userId,
                        role: "member",
                        status: "active",
                        access_role: normalizeAccessRole(invite.accessRole) ?? HouseholdAccessRole.observer.rawValue,
                        family_role: nil,
                        relationship_label: normalizeRelationshipLabel(invite.relationship),
                        invited_by_user_id: invite.invitedBy,
                        created_at: now,
                        updated_at: now
                    )],
                    session: session,
                    context: WriteDiagnosticContext(
                        operation: "acceptPendingInvitesForSignedInUser",
                        tableOrEndpoint: "household_memberships",
                        payloadSummary: "household_id=\(invite.householdId.uuidString), user_id=\(userId.uuidString), status=active"
                    )
                ) as [BackendHouseholdMembership]
#if DEBUG
                print("[InviteAccept] membership created=true (REST)")
#endif
            }
            _ = try await patch(
                path: "household_invites?id=eq.\(invite.id.uuidString)",
                payload: UpdateInviteClaimRequest(
                    status: InviteStatus.accepted.rawValue,
                    claimed_by_user_id: userId,
                    claimed_at: now,
                    updated_at: now
                ),
                session: session,
                context: WriteDiagnosticContext(
                    operation: "acceptPendingInvitesForSignedInUser",
                    tableOrEndpoint: "household_invites",
                    payloadSummary: "invite_id=\(invite.id.uuidString), status=accepted"
                )
            ) as [BackendHouseholdInvite]
        }
    }

    private func consumePendingInvitesForEmail(
        householdId: UUID,
        email: String,
        claimedByUserId: UUID,
        session: AuthUserSession
    ) async throws {
        let path = "household_invites?select=*&household_id=eq.\(householdId.uuidString)&email=eq.\(encodeQueryValue(email))&status=eq.\(InviteStatus.pending.rawValue)"
        let pendingInvites: [BackendHouseholdInvite] = try await get(path: path, session: session)
        guard !pendingInvites.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        for invite in pendingInvites {
            _ = try await patch(
                path: "household_invites?id=eq.\(invite.id.uuidString)",
                payload: UpdateInviteClaimRequest(
                    status: InviteStatus.accepted.rawValue,
                    claimed_by_user_id: claimedByUserId,
                    claimed_at: now,
                    updated_at: now
                ),
                session: session,
                context: WriteDiagnosticContext(
                    operation: "consumePendingInvitesForEmail",
                    tableOrEndpoint: "household_invites",
                    payloadSummary: "invite_id=\(invite.id.uuidString), status=accepted, claimed_by=\(claimedByUserId.uuidString)"
                )
            ) as [BackendHouseholdInvite]
        }
#if DEBUG
        print(
            "[HouseholdBackendService] consumed pending invites household_id=\(householdId.uuidString), " +
            "email=\(email), count=\(pendingInvites.count)"
        )
#endif
    }

    private func fetchHouseholdById(_ householdId: UUID, session: AuthUserSession) async throws -> BackendHousehold {
        let path = "households?select=*&id=eq.\(householdId.uuidString.lowercased())&limit=1"
        let rows: [BackendHousehold] = try await get(path: path, session: session)
        guard let household = rows.first else {
            throw ServiceError.joinCodeNotFound
        }
        return household
    }

    private static func defaultInviteExpiresAtISO8601() -> String {
        let calendar = Calendar(identifier: .gregorian)
        let expires = calendar.date(byAdding: DateComponents(day: 30), to: Date()) ?? Date().addingTimeInterval(86400 * 30)
        return ISO8601DateFormatter().string(from: expires)
    }

    private func nextUniqueInviteCode(session: AuthUserSession) async throws -> String {
        var attempts = 0
        while attempts < 16 {
            attempts += 1
            let candidate = generateHouseholdInviteCode(length: 8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            if try await !householdInviteCodeExists(candidate, session: session),
               try await !inviteRowCodeExists(candidate, session: session) {
                return candidate
            }
        }
        throw ServiceError.requestFailed("Unable to generate a unique invite code. Please try again.")
    }

    private func inviteRowCodeExists(_ code: String, session: AuthUserSession) async throws -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let path = "household_invites?select=id&invite_code=ilike.\(encodeQueryValue(normalized))&limit=1"
        let rows: [HouseholdIdResponse] = try await get(path: path, session: session)
        return rows.first != nil
    }

    private func resolveSignedInUserEmail(session: AuthUserSession) async throws -> String? {
        if let sessionEmail = session.email?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sessionEmail.isEmpty {
            return sessionEmail.lowercased()
        }
        guard let userId = UUID(uuidString: session.userId) else {
            throw ServiceError.invalidUserId
        }
        let profiles: [BackendProfile] = try await get(
            path: "profiles?select=email&id=eq.\(userId.uuidString)&limit=1",
            session: session
        )
        return profiles.first?.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
