import Foundation

enum ExternalLinks {
    static let website = "https://tribeboard.app"
    static let privacyPolicy = "https://tribeboard.app/legal/privacy-policy"
    static let termsOfService = "https://tribeboard.app/legal/terms"
    static let childSafetyPolicy = "https://tribeboard.app/legal/child-safety"
    static let cookiePolicy = "https://tribeboard.app/legal/cookie-policy"
    static let communityGuidelines = "https://tribeboard.app/legal/community-guidelines"
    static let deleteAccountPolicy = "https://tribeboard.app/delete-account"

    static let supportEmail = "support@tribeboard.app"
    static let privacyEmail = "privacy@tribeboard.app"
    static let legalEmail = "legal@tribeboard.app"
    static let securityEmail = "security@tribeboard.app"

    static var appDisplayName: String {
        let bundle = Bundle.main
        if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !displayName.isEmpty {
            return displayName
        }
        if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty {
            return name
        }
        return "TribeBoard"
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var appVersionBuildText: String {
        "v\(appVersion) (\(appBuild))"
    }

    static func emailURL(
        to address: String,
        subject: String = "",
        body: String = ""
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        var queryItems: [URLQueryItem] = []
        if !subject.isEmpty {
            queryItems.append(URLQueryItem(name: "subject", value: subject))
        }
        if !body.isEmpty {
            queryItems.append(URLQueryItem(name: "body", value: body))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url
    }

    static func supportEmailURL(subject: String = "TribeBoard Support", body: String = "") -> URL? {
        emailURL(to: supportEmail, subject: subject, body: body)
    }

    static func securityConcernEmailURL(body: String = "") -> URL? {
        emailURL(
            to: securityEmail,
            subject: "TribeBoard Safety Concern",
            body: body
        )
    }
}
