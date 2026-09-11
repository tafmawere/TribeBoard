import Foundation
import GoogleSignIn
import UIKit

struct GoogleSignInResult {
    let idToken: String
    let accessToken: String?
    let email: String?
    let fullName: String?
    let avatarURL: URL?
}

final class GoogleSignInService {
    enum GoogleSignInError: LocalizedError {
        case notConfigured
        case presentationUnavailable
        case identityTokenMissing
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Google sign-in is not available for this build."
            case .presentationUnavailable:
                return "Google sign-in is not available for this build."
            case .identityTokenMissing:
                return "Google sign-in could not be completed. Please try again."
            case .cancelled:
                return "Google sign-in was cancelled."
            case .failed(let message):
                return message
            }
        }
    }

    @MainActor
    func beginSignIn() async throws -> GoogleSignInResult {
        guard GoogleSignInConfig.isConfigured else {
            throw GoogleSignInError.notConfigured
        }
        GoogleSignInBootstrap.configureIfNeeded()

        guard let presentingViewController = Self.topViewController() else {
            throw GoogleSignInError.presentationUnavailable
        }

        do {
            let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            guard let idToken = signInResult.user.idToken?.tokenString,
                  !idToken.isEmpty else {
                throw GoogleSignInError.identityTokenMissing
            }

            let profile = signInResult.user.profile
            let fullName = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            let email = profile?.email.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            let avatarURL = profile?.imageURL(withDimension: 256)

            let accessToken = signInResult.user.accessToken.tokenString.nilIfEmpty

            return GoogleSignInResult(
                idToken: idToken,
                accessToken: accessToken,
                email: email,
                fullName: fullName,
                avatarURL: avatarURL
            )
        } catch let error as GIDSignInError where error.code == .canceled {
            throw GoogleSignInError.cancelled
        } catch let error as GoogleSignInError {
            throw error
        } catch {
            throw GoogleSignInError.failed("Google sign-in could not be completed. Please try again.")
        }
    }

    @MainActor
    static func handleOpenURL(_ url: URL) -> Bool {
        guard GoogleSignInConfig.isConfigured else { return false }
        GoogleSignInBootstrap.configureIfNeeded()
        return GIDSignIn.sharedInstance.handle(url)
    }

    @MainActor
    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root: UIViewController? = {
            if let base { return base }
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            for scene in scenes {
                if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) {
                    return keyWindow.rootViewController
                }
            }
            return scenes.first?.windows.first?.rootViewController
        }()

        if let navigation = root as? UINavigationController {
            return topViewController(base: navigation.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
