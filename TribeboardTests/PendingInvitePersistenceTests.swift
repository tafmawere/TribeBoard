import XCTest
@testable import Tribeboard

final class PendingInvitePersistenceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "tb.tests.pendingInvite.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRoundTripPreservesInviteIdAndCodeWithNullToken() {
        let inviteId = UUID()
        let householdId = UUID()
        PendingInvitePersistence.save(
            code: "h-ab12cd34",
            token: nil,
            inviteId: inviteId,
            householdId: householdId,
            email: "Rue@Example.com",
            userDefaults: defaults
        )

        let loaded = PendingInvitePersistence.load(userDefaults: defaults)
        XCTAssertEqual(loaded?.inviteId, inviteId)
        XCTAssertEqual(loaded?.inviteCode, "H-AB12CD34")
        XCTAssertNil(loaded?.inviteToken)
        XCTAssertEqual(loaded?.householdId, householdId)
        XCTAssertEqual(loaded?.invitedEmail, "rue@example.com")
        XCTAssertFalse(loaded?.prefersToken ?? true)
    }

    func testBlankTokenIsStoredAsNil() {
        PendingInvitePersistence.save(
            code: "H-ZZZZYYYY",
            token: "   ",
            inviteId: UUID(),
            userDefaults: defaults
        )
        let loaded = PendingInvitePersistence.load(userDefaults: defaults)
        XCTAssertNil(loaded?.inviteToken)
        XCTAssertEqual(loaded?.inviteCode, "H-ZZZZYYYY")
    }

    func testClearRemovesSnapshot() {
        PendingInvitePersistence.save(code: "H-11111111", token: nil, inviteId: UUID(), userDefaults: defaults)
        XCTAssertNotNil(PendingInvitePersistence.load(userDefaults: defaults))
        PendingInvitePersistence.clear(userDefaults: defaults, reason: "test")
        XCTAssertNil(PendingInvitePersistence.load(userDefaults: defaults))
    }

    func testParseInviteLinkExtractsIdCodeAndOptionalToken() {
        let inviteId = UUID()
        let url = URL(
            string: "https://tribeboard.app/invite/\(inviteId.uuidString)?invite_code=h-code99aa&email=a@b.com"
        )!
        let parsed = PendingInvitePersistence.parseInviteLink(url)
        XCTAssertEqual(parsed?.inviteId, inviteId)
        XCTAssertEqual(parsed?.inviteCode, "H-CODE99AA")
        XCTAssertEqual(parsed?.email, "a@b.com")
        XCTAssertEqual(parsed?.token, inviteId.uuidString.lowercased())
    }

    func testParseInviteLinkAllowsCodeOnlyWithoutToken() {
        let url = URL(string: "tribeboard://join?invite_code=h-onlycode")!
        let parsed = PendingInvitePersistence.parseInviteLink(url)
        XCTAssertNil(parsed?.token)
        XCTAssertEqual(parsed?.inviteCode, "H-ONLYCODE")
        XCTAssertNil(parsed?.inviteId)
    }

    func testIngestInviteURLRoundTripsThroughIsolatedDefaults() {
        let inviteId = UUID()
        let url = URL(string: "https://tribeboard.app/invite?invite_id=\(inviteId.uuidString)&invite_code=h-persist1")!
        XCTAssertTrue(PendingInvitePersistence.ingestInviteURL(url, userDefaults: defaults))
        let loaded = PendingInvitePersistence.load(userDefaults: defaults)
        XCTAssertEqual(loaded?.inviteId, inviteId)
        XCTAssertEqual(loaded?.inviteCode, "H-PERSIST1")
    }

    func testIgnoresUnrelatedURL() {
        let url = URL(string: "https://example.com/invite?invite_code=H-XXXX")!
        XCTAssertNil(PendingInvitePersistence.parseInviteLink(url))
        XCTAssertFalse(PendingInvitePersistence.ingestInviteURL(url, userDefaults: defaults))
        XCTAssertNil(PendingInvitePersistence.load(userDefaults: defaults))
    }
}

final class InviteAcceptCredentialResolverTests: XCTestCase {
    func testPrefersInviteIdOverTokenAndCode() {
        let inviteId = UUID()
        let resolved = InviteAcceptCredentialResolver.resolve(
            inviteId: inviteId,
            inviteToken: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            inviteCode: "H-FALLBACK"
        )
        XCTAssertEqual(resolved, .inviteId(inviteId))
    }

    func testFallsBackToCodeWhenTokenIsNull() {
        XCTAssertEqual(
            InviteAcceptCredentialResolver.resolve(
                inviteId: nil,
                inviteToken: nil,
                inviteCode: "  h-codeok  "
            ),
            .inviteCode("h-codeok")
        )
    }

    func testBlankTokenIsNormalAndDoesNotWin() {
        XCTAssertEqual(
            InviteAcceptCredentialResolver.resolve(
                inviteId: nil,
                inviteToken: "   ",
                inviteCode: "H-CODE"
            ),
            .inviteCode("H-CODE")
        )
    }

    func testUsesTokenWhenIdMissingAndTokenPresent() {
        XCTAssertEqual(
            InviteAcceptCredentialResolver.resolve(
                inviteId: nil,
                inviteToken: " BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB ",
                inviteCode: "H-CODE"
            ),
            .inviteToken("BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")
        )
    }

    func testSnapshotAndNullPreviewTokenResolveToIdThenCode() {
        let inviteId = UUID()
        let snapshot = PendingInviteSnapshot(
            inviteCode: "H-SNAP",
            inviteToken: nil,
            inviteId: inviteId,
            householdId: UUID(),
            invitedEmail: "a@b.com",
            savedAt: Date()
        )
        XCTAssertEqual(InviteAcceptCredentialResolver.resolve(snapshot), .inviteId(inviteId))

        let preview = HouseholdInvitePreview(
            inviteId: inviteId,
            householdId: UUID(),
            householdName: "Tribe",
            inviterDisplayName: "Rue",
            accessRole: "observer",
            relationship: nil,
            status: "pending",
            expiresAt: nil,
            inviteToken: nil,
            backupInviteCode: "H-BACKUP"
        )
        XCTAssertNil(preview.inviteToken)
        XCTAssertEqual(InviteAcceptCredentialResolver.resolve(preview), .inviteId(inviteId))
        XCTAssertTrue(preview.isPendingAndNotExpired)
    }

    func testDecodesPreviewWithNullInviteToken() throws {
        let inviteId = UUID()
        let householdId = UUID()
        let json = """
        {
          "invite_id": "\(inviteId.uuidString)",
          "household_id": "\(householdId.uuidString)",
          "household_name": "Mawere",
          "inviter_display_name": "Rue",
          "access_role": "driver",
          "relationship": null,
          "status": "pending",
          "expires_at": null,
          "invite_token": null,
          "backup_invite_code": "H-DECODE1"
        }
        """.data(using: .utf8)!
        let preview = try JSONDecoder().decode(HouseholdInvitePreview.self, from: json)
        XCTAssertNil(preview.inviteToken)
        XCTAssertEqual(preview.backupInviteCode, "H-DECODE1")
        XCTAssertEqual(
            InviteAcceptCredentialResolver.resolve(preview),
            .inviteId(inviteId)
        )
    }
}
