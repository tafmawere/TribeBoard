import XCTest
@testable import Tribeboard

final class NotificationLiveDataTests: XCTestCase {
    func testLiveInboxStartsEmpty() {
        XCTAssertTrue(NotificationInboxBootstrap.liveItems.isEmpty)
        XCTAssertFalse(NotificationMockData.inboxItems.isEmpty)
    }

    func testLiveContactsIgnoreMockNamesAndChildren() {
        let householdId = UUID()
        let people = [
            BackendHouseholdPerson(
                id: UUID(),
                householdId: householdId,
                name: "Alex Rivera",
                relationship: "Driver",
                role: "driver",
                phone: nil,
                isDriver: true,
                createdAt: nil,
                updatedAt: nil
            ),
            BackendHouseholdPerson(
                id: UUID(),
                householdId: householdId,
                name: "Kid",
                relationship: "Child",
                role: "child",
                phone: "+15550109999",
                isDriver: false,
                createdAt: nil,
                updatedAt: nil
            ),
            BackendHouseholdPerson(
                id: UUID(),
                householdId: householdId,
                name: "Jordan Lee",
                relationship: "Parent",
                role: "parent",
                phone: "+15550108452",
                isDriver: false,
                createdAt: nil,
                updatedAt: nil
            ),
            BackendHouseholdPerson(
                id: UUID(),
                householdId: householdId,
                name: "Sam Driver",
                relationship: "Driver",
                role: "driver",
                phone: "+15550102333",
                isDriver: true,
                createdAt: nil,
                updatedAt: nil
            )
        ]

        let mapped = NotificationLiveContacts.from(people: people)
        XCTAssertEqual(mapped.drivers.map(\.name), ["Sam Driver"])
        XCTAssertEqual(mapped.parents.map(\.name), ["Jordan Lee"])
        XCTAssertFalse(mapped.drivers.contains(where: { $0.name == "Alex Rivera" }))
    }
}
