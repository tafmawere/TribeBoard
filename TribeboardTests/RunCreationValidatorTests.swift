import XCTest
@testable import Tribeboard

final class RunCreationValidatorTests: XCTestCase {
    func testRejectsMissingDepartureTime() {
        let run = SystemDomain.RunInstance(
            id: UUID(),
            householdId: UUID(),
            templateId: UUID(),
            title: "School run",
            date: Date(),
            departureTime: " ",
            status: .scheduled,
            stops: [],
            stopSnapshots: [],
            driverId: nil,
            childId: UUID(),
            createdAt: Date()
        )

        XCTAssertThrowsError(try RunCreationValidator.validate(run)) { error in
            guard let validationError = error as? RunCreationValidator.ValidationError else {
                return XCTFail("Expected ValidationError, got \(error)")
            }
            XCTAssertEqual(validationError, .missingDepartureTime)
        }
    }

    func testAcceptsValidRunSnapshot() throws {
        let date = Date()
        let run = SystemDomain.RunInstance(
            id: UUID(),
            householdId: UUID(),
            templateId: UUID(),
            title: "School run",
            date: date,
            departureTime: RunScheduledTime.from(date: date),
            status: .scheduled,
            stops: [],
            stopSnapshots: [],
            driverId: nil,
            childId: UUID(),
            createdAt: Date()
        )

        XCTAssertNoThrow(try RunCreationValidator.validate(run))
    }
}
