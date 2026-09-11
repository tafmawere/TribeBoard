import XCTest
@testable import Tribeboard

final class SupabaseJSONCodingTests: XCTestCase {
    func testDecodesPostgresDateOnlyRunDate() throws {
        let json = """
        [{
          "id": "9ECB2598-DBC9-453B-8F99-CCA77A40278D",
          "household_id": "11111111-1111-1111-1111-111111111111",
          "schedule_id": "22222222-2222-2222-2222-222222222222",
          "child_id": "44444444-4444-4444-4444-444444444444",
          "title": "Play date",
          "run_date": "2026-06-23",
          "departure_time": "07:45:00",
          "status": "assigned",
          "driver_id": "33333333-3333-3333-3333-333333333333",
          "created_at": "2026-06-23T10:15:30.123456+00:00"
        }]
        """.data(using: .utf8)!

        let runs = try SupabaseJSONCoding.makeSupabaseDecoder().decode([BackendRun].self, from: json)
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].status, "assigned")
        XCTAssertEqual(runs[0].title, "Play date")
        XCTAssertEqual(runs[0].departureTime, "07:45:00")
        XCTAssertEqual(
            BackendTimestampParser.formatDateOnly(runs[0].runDate),
            "2026-06-23"
        )
    }

    func testDecodesRunStopWithChildIdAndStopOrder() throws {
        let json = """
        [{
          "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
          "run_id": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
          "child_id": "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC",
          "label": "Pickup",
          "latitude": -26.1459235,
          "longitude": 28.0417979,
          "stop_order": 0,
          "status": "pending",
          "location_id": null,
          "arrived_at": null,
          "departed_at": null
        }]
        """.data(using: .utf8)!

        let stops = try SupabaseJSONCoding.makeSupabaseDecoder().decode([BackendRunStop].self, from: json)
        XCTAssertEqual(stops[0].stopOrder, 0)
        XCTAssertEqual(stops[0].childId.uuidString, "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")
    }

    func testDecodesRunStopLifecycleTimestamps() throws {
        let json = """
        [{
          "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
          "run_id": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
          "child_id": "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC",
          "label": "Pickup",
          "latitude": -26.1459235,
          "longitude": 28.0417979,
          "stop_order": 0,
          "status": "arrived",
          "location_id": null,
          "arrived_at": "2026-06-24T07:15:00+00:00",
          "departed_at": null
        }]
        """.data(using: .utf8)!

        let stops = try SupabaseJSONCoding.makeSupabaseDecoder().decode([BackendRunStop].self, from: json)
        XCTAssertEqual(stops[0].status, "arrived")
        XCTAssertNotNil(stops[0].arrivedAt)
        XCTAssertNil(stops[0].departedAt)
    }

    func testRunStopInsertPayloadEncodesLifecycleTimestamps() throws {
        let stop = BackendRunStop(
            id: UUID(),
            runId: UUID(),
            childId: UUID(),
            label: "Dropoff",
            latitude: -26.2,
            longitude: 28.1,
            stopOrder: 1,
            status: "completed",
            locationId: nil,
            arrivedAt: Date(timeIntervalSince1970: 1_700_000_000),
            departedAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
        let payload = BackendRunStopInsertPayload(from: stop)
        let data = try SupabaseJSONCoding.makeSupabaseEncoder().encode([payload])
        let object = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let row = try XCTUnwrap(object?.first)
        XCTAssertEqual(row["status"] as? String, "completed")
        XCTAssertNotNil(row["arrived_at"])
        XCTAssertNotNil(row["departed_at"])
    }

    func testRunStopStatusCodecDecodesActiveAsArrived() {
        XCTAssertEqual(BackendRunStopStatusCodec.decode("active"), .arrived)
    }

    func testDecodesRunLifecycleTimestamps() throws {
        let json = """
        [{
          "id": "9ECB2598-DBC9-453B-8F99-CCA77A40278D",
          "household_id": "11111111-1111-1111-1111-111111111111",
          "schedule_id": "22222222-2222-2222-2222-222222222222",
          "child_id": "44444444-4444-4444-4444-444444444444",
          "title": "School run",
          "run_date": "2026-06-23",
          "departure_time": "07:45:00",
          "status": "completed",
          "driver_id": "33333333-3333-3333-3333-333333333333",
          "started_at": "2026-06-23T07:50:00+00:00",
          "completed_at": "2026-06-23T08:20:00+00:00",
          "cancelled_at": null,
          "created_at": "2026-06-23T06:15:30+00:00"
        }]
        """.data(using: .utf8)!

        let runs = try SupabaseJSONCoding.makeSupabaseDecoder().decode([BackendRun].self, from: json)
        XCTAssertNotNil(runs[0].startedAt)
        XCTAssertNotNil(runs[0].completedAt)
        XCTAssertNil(runs[0].cancelledAt)
    }

    func testDescribeDecodingErrorForKeyNotFound() {
        let json = """
        [{"id":"11111111-1111-1111-1111-111111111111"}]
        """.data(using: .utf8)!
        do {
            _ = try SupabaseJSONCoding.makeSupabaseDecoder().decode([BackendRun].self, from: json)
            XCTFail("Expected decode failure")
        } catch {
            let message = SupabaseJSONCoding.describeDecodingError(error)
            XCTAssertTrue(message.contains("DecodingError"))
        }
    }
}
