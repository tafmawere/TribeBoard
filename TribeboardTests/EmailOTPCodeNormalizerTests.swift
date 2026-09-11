import XCTest
@testable import Tribeboard

final class EmailOTPCodeNormalizerTests: XCTestCase {
    func testPreservesLeadingZerosFromSpacedEmailToken() {
        XCTAssertEqual(EmailOTPCodeNormalizer.normalize("0 5 0 8 0 5 8 6"), "05080586")
    }

    func testPreservesLeadingZerosWithoutSpaces() {
        XCTAssertEqual(EmailOTPCodeNormalizer.normalize("05080586"), "05080586")
    }

    func testValidLengthAcceptsSixThroughTenDigits() {
        XCTAssertTrue(EmailOTPCodeNormalizer.isValidLength("123456"))
        XCTAssertTrue(EmailOTPCodeNormalizer.isValidLength("05080586"))
        XCTAssertTrue(EmailOTPCodeNormalizer.isValidLength("1234567890"))
        XCTAssertFalse(EmailOTPCodeNormalizer.isValidLength("12345"))
        XCTAssertFalse(EmailOTPCodeNormalizer.isValidLength("12345678901"))
    }
}
