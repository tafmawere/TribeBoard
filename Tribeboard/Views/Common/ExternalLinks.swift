import Foundation

enum ExternalLinks {
    static let website = "https://www.example.com"
    static let privacyPolicy = "https://www.example.com/privacy"
    static let termsOfService = "https://www.example.com/terms"
    static let supportEmail = "support@example.com"

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

    static func supportEmailURL(subject: String = "TribeBoard Support", body: String = "") -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}
