import XCTest
@testable import Tribeboard

final class DebugAndDemoIsolationTests: XCTestCase {
    func testReleaseCannotEnableSkipOnboardingUnlessDebug() {
#if DEBUG
        XCTAssertTrue(DebugFlags.skipOnboarding)
        XCTAssertTrue(DebugFlags.allowsDebugBypasses)
        XCTAssertTrue(AppConfig.isDemoFlowEnabled)
#else
        XCTAssertFalse(DebugFlags.skipOnboarding)
        XCTAssertFalse(DebugFlags.allowsDebugBypasses)
        XCTAssertFalse(AppConfig.isDemoFlowEnabled)
#endif
    }

    func testOnboardingForceFlagIsIgnoredOutsideDebug() {
        OnboardingTestingPreferences.forceOnboardingOnNextLaunch = true
#if DEBUG
        XCTAssertTrue(OnboardingTestingPreferences.forceOnboardingOnNextLaunch)
#else
        XCTAssertFalse(OnboardingTestingPreferences.forceOnboardingOnNextLaunch)
#endif
        OnboardingTestingPreferences.clearForceOnboardingOnNextLaunch()
        XCTAssertFalse(OnboardingTestingPreferences.forceOnboardingOnNextLaunch)
    }

    func testFamilyMemberDisplayDoesNotTreatDemoIdsAsParents() {
        let member = FamilyMemberDisplay.from(
            userId: "rue-demo-id",
            displayName: "Rue",
            role: .observer
        )
        XCTAssertFalse(member.isParent)
        XCTAssertEqual(member.avatarInitials, "RU")
    }

    func testFamilyMemberDisplayMarksAdminAsParent() {
        let member = FamilyMemberDisplay.from(
            userId: UUID().uuidString,
            displayName: "Alex Organiser",
            role: .admin
        )
        XCTAssertTrue(member.isParent)
        XCTAssertTrue(member.roleBadges.contains(where: { $0.name == "Parent" }))
    }
}
