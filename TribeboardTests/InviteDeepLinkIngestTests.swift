import XCTest
@testable import Tribeboard

final class InviteDeepLinkIngestTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "tb.tests.inviteIngest.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSignedOutDeepLinkRetainsPendingSnapshot() {
        let inviteId = UUID()
        let householdId = UUID()
        let url = URL(
            string: "https://tribeboard.app/invite/\(inviteId.uuidString)?invite_code=h-signedout&email=Rue@Example.com&household_id=\(householdId.uuidString)"
        )!

        let step = InviteDeepLinkIngest.handle(
            url: url,
            isAuthenticated: false,
            userDefaults: defaults
        )

        XCTAssertEqual(step, .savedForSignIn)
        XCTAssertEqual(InviteDeepLinkIngest.savedForSignInBanner, "We saved your invite. Sign in or create an account to finish joining.")

        let loaded = PendingInvitePersistence.load(userDefaults: defaults)
        XCTAssertEqual(loaded?.inviteId, inviteId)
        XCTAssertEqual(loaded?.inviteCode, "H-SIGNEDOUT")
        XCTAssertEqual(loaded?.invitedEmail, "rue@example.com")
        XCTAssertEqual(loaded?.householdId, householdId)
        XCTAssertNotNil(loaded?.savedAt)
        XCTAssertEqual(
            InviteAcceptCredentialResolver.resolve(loaded!),
            .inviteId(inviteId)
        )
    }

    func testSignedInDeepLinkStillPersistsThenEvaluatesPostAuth() {
        let url = URL(string: "tribeboard://join?invite_code=h-authed01")!
        let step = InviteDeepLinkIngest.handle(
            url: url,
            isAuthenticated: true,
            userDefaults: defaults
        )
        XCTAssertEqual(step, .evaluatePostAuth)
        XCTAssertEqual(PendingInvitePersistence.load(userDefaults: defaults)?.inviteCode, "H-AUTHED01")
    }

    func testUnrelatedURLDoesNotWriteSnapshot() {
        let url = URL(string: "https://example.com/invite?invite_code=H-XXXX")!
        XCTAssertEqual(
            InviteDeepLinkIngest.handle(url: url, isAuthenticated: false, userDefaults: defaults),
            .ignored
        )
        XCTAssertNil(PendingInvitePersistence.load(userDefaults: defaults))
    }
}
