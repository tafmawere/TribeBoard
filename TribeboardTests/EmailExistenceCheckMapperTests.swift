import XCTest
@testable import Tribeboard

final class EmailExistenceCheckMapperTests: XCTestCase {
    func testDecodesExistsTrue() {
        let body = Data(#"{"exists":true}"#.utf8)
        XCTAssertEqual(EmailExistenceCheckMapper.mapHTTP(statusCode: 200, body: body), .exists)
    }

    func testDecodesExistsFalse() {
        let body = Data(#"{"exists":false}"#.utf8)
        XCTAssertEqual(EmailExistenceCheckMapper.mapHTTP(statusCode: 200, body: body), .doesNotExist)
    }

    func testUndecodableSuccessIsUnavailable() {
        let body = Data(#"{"ok":true}"#.utf8)
        XCTAssertEqual(EmailExistenceCheckMapper.mapHTTP(statusCode: 200, body: body), .unavailable)
    }

    func testMissingFunctionStatusesAreUnavailable() {
        for status in [404, 501, 502, 503, 504] {
            XCTAssertEqual(
                EmailExistenceCheckMapper.mapHTTP(statusCode: status, body: Data()),
                .unavailable,
                "status \(status) should be unavailable"
            )
        }
    }

    func testFunctionNotFoundBodyIsUnavailable() {
        let body = Data(#"{"code":"FUNCTION_NOT_FOUND","message":"Requested function was not found"}"#.utf8)
        XCTAssertEqual(EmailExistenceCheckMapper.mapHTTP(statusCode: 400, body: body), .unavailable)
    }

    func testOtherClientErrorKeepsFailedMessage() {
        let body = Data(#"{"message":"Enter a valid email address."}"#.utf8)
        XCTAssertEqual(
            EmailExistenceCheckMapper.mapHTTP(statusCode: 422, body: body),
            .failed(message: "Enter a valid email address.")
        )
    }

    func testTransportErrorIsUnavailable() {
        XCTAssertEqual(
            EmailExistenceCheckMapper.mapTransportError(URLError(.notConnectedToInternet)),
            .unavailable
        )
    }

    func testCancellationIsFailedNotExists() {
        XCTAssertEqual(
            EmailExistenceCheckMapper.mapTransportError(CancellationError()),
            .failed(message: "Cancelled")
        )
    }
}
