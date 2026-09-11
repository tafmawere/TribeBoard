import Foundation

#if DEBUG
enum AuthDebugLog {
    static func verifyRequest(
        email: String,
        normalizedOTP: String,
        verifyType: String,
        endpoint: String
    ) {
        let payloadPreview = """
        {"email":"\(email)","token":"\(normalizedOTP)","type":"\(verifyType)"}
        """
        print(
            """
            [Auth][verify] request
              email=\(email)
              otpLength=\(normalizedOTP.count)
              otpMasked=\(EmailOTPCodeNormalizer.masked(normalizedOTP))
              type=\(verifyType)
              endpoint=\(endpoint)
              payload=\(payloadPreview)
            """
        )
    }

    static func verifyResponse(statusCode: Int, data: Data?) {
        let body = data.flatMap { String(data: $0, encoding: .utf8) }
        if let body, !body.isEmpty {
            if let parsed = parseAuthError(data: data) {
                print(
                    """
                    [Auth][verify] response status=\(statusCode) \
                    error_code=\(parsed.errorCode ?? "nil") msg=\(parsed.message ?? "nil")
                    body=\(body)
                    """
                )
            } else {
                print("[Auth][verify] response status=\(statusCode) body=\(body)")
            }
        } else {
            print("[Auth][verify] response status=\(statusCode)")
        }
    }

    static func verifyFallback(from failedType: String, to nextType: String) {
        print("[Auth][verify] retrying type=\(nextType) after \(failedType) failed with invalid/expired OTP")
    }

    static func resendAttempt(email: String) {
        print("[Auth][verify] resend email=\(email)")
    }

    static func signupRedirect(emailRedirectTo: String) {
        print("[Auth][signup] email_redirect_to=\(emailRedirectTo)")
    }

    private struct ParsedAuthError {
        let errorCode: String?
        let message: String?
    }

    private static func parseAuthError(data: Data?) -> ParsedAuthError? {
        guard let data else { return nil }
        struct Payload: Decodable {
            let msg: String?
            let message: String?
            let error_description: String?
            let error_code: String?
        }
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }
        return ParsedAuthError(
            errorCode: decoded.error_code,
            message: decoded.msg ?? decoded.error_description ?? decoded.message
        )
    }
}
#endif
