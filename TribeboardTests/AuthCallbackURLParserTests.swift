import XCTest
@testable import Tribeboard

final class AuthCallbackURLParserTests: XCTestCase {
    func testRecognizesCustomSchemeCallback() {
        let url = URL(string: "tribeboard://auth/callback#access_token=abc&refresh_token=def&expires_in=3600")!
        XCTAssertTrue(AuthCallbackURLParser.isAuthCallbackURL(url))
        let parsed = AuthCallbackURLParser.parseSession(from: url)
        XCTAssertEqual(parsed?.accessToken, "abc")
        XCTAssertEqual(parsed?.refreshToken, "def")
        XCTAssertEqual(parsed?.expiresIn, 3600)
    }

    func testRecognizesUniversalLinkHost() {
        let url = URL(string: "https://tribeboard.app/auth/callback?access_token=token-1")!
        XCTAssertTrue(AuthCallbackURLParser.isAuthCallbackURL(url))
        XCTAssertEqual(AuthCallbackURLParser.parseSession(from: url)?.accessToken, "token-1")
    }

    func testIgnoresUnrelatedURL() {
        let url = URL(string: "https://tribeboard.app/invite/abc")!
        XCTAssertFalse(AuthCallbackURLParser.isAuthCallbackURL(url))
        XCTAssertNil(AuthCallbackURLParser.parseSession(from: url))
    }

    func testMissingAccessTokenReturnsNil() {
        let url = URL(string: "tribeboard://auth/callback#refresh_token=only")!
        XCTAssertNil(AuthCallbackURLParser.parseSession(from: url))
    }
}
