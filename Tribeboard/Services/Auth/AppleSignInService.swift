import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

struct AppleSignInResult {
    let identityToken: String
    let nonce: String
    let email: String?
    let fullName: PersonNameComponents?
}

final class AppleSignInService: NSObject {
    enum AppleSignInError: LocalizedError {
        case presentationAnchorUnavailable
        case identityTokenMissing
        case identityTokenEncodingFailed
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .presentationAnchorUnavailable:
                return "Apple sign-in is not available for this build."
            case .identityTokenMissing, .identityTokenEncodingFailed:
                return "Apple sign-in could not be completed. Please try again."
            case .cancelled:
                return "Apple sign-in was cancelled."
            case .failed(let message):
                return message
            }
        }
    }

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var activeNonce: String?
    private var authorizationController: ASAuthorizationController?
    private var presentationProvider: PresentationProvider?

    @MainActor
    func beginSignIn() async throws -> AppleSignInResult {
        guard let anchor = Self.presentationAnchor() else {
            throw AppleSignInError.presentationAnchorUnavailable
        }

        let nonce = Self.randomNonceString()
        activeNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let presentationProvider = PresentationProvider(anchor: anchor)
        controller.delegate = self
        controller.presentationContextProvider = presentationProvider
        self.authorizationController = controller
        self.presentationProvider = presentationProvider

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)

        var remainingLength = length
        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if errorCode != errSecSuccess {
                return UUID().uuidString.replacingOccurrences(of: "-", with: "")
            }
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private static func presentationAnchor() -> ASPresentationAnchor? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
        }
        return scenes.first?.windows.first
    }

    private func finish() {
        continuation = nil
        activeNonce = nil
        authorizationController = nil
        presentationProvider = nil
    }
}

extension AppleSignInService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let continuation else { return }
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                continuation.resume(throwing: AppleSignInError.failed("Apple sign-in could not be completed. Please try again."))
                finish()
                return
            }
            guard let nonce = activeNonce else {
                continuation.resume(throwing: AppleSignInError.failed("Apple sign-in could not be completed. Please try again."))
                finish()
                return
            }
            guard let identityTokenData = credential.identityToken else {
                continuation.resume(throwing: AppleSignInError.identityTokenMissing)
                finish()
                return
            }
            guard let token = String(data: identityTokenData, encoding: .utf8), !token.isEmpty else {
                continuation.resume(throwing: AppleSignInError.identityTokenEncodingFailed)
                finish()
                return
            }
            continuation.resume(
                returning: AppleSignInResult(
                    identityToken: token,
                    nonce: nonce,
                    email: credential.email,
                    fullName: credential.fullName
                )
            )
            finish()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            guard let continuation else { return }
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                continuation.resume(throwing: AppleSignInError.cancelled)
            } else {
                continuation.resume(throwing: AppleSignInError.failed("Apple sign-in could not be completed. Please try again."))
            }
            finish()
        }
    }
}

private final class PresentationProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    private let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor
    }
}

// Manual setup required in Xcode:
// Target -> Signing & Capabilities -> add "Sign in with Apple".
