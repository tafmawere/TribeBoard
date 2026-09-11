import Foundation

enum AvatarURLResolver {
    private static let signedURLCache = NSCache<NSString, NSURL>()

    static func resolveUploadedURL(
        _ reference: String?,
        accessToken: String?,
        expiresIn: Int = 3600
    ) async -> URL? {
        guard let reference = reference?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
            return nil
        }
        if reference.hasPrefix("http://") || reference.hasPrefix("https://") {
            return URL(string: reference)
        }
        if reference.hasPrefix("file://") {
            return URL(string: reference)
        }
        if let local = AvatarPhotoStore.resolvePhotoURL(from: reference), local.isFileURL {
            return local
        }
        guard let accessToken, !accessToken.isEmpty else { return nil }

        let cacheKey = "\(reference)|\(accessToken.prefix(12))" as NSString
        if let cached = signedURLCache.object(forKey: cacheKey) as URL? {
            return cached
        }

        guard let signed = await AvatarBackendService().createSignedURL(
            storagePath: normalizedStoragePath(reference),
            accessToken: accessToken,
            expiresIn: expiresIn
        ) else {
            return nil
        }
        signedURLCache.setObject(signed as NSURL, forKey: cacheKey)
        return signed
    }

    static func storagePath(profileId: UUID, fileName: String = "avatar.jpg") -> String {
        "\(profileId.uuidString.lowercased())/\(fileName)"
    }

    static func normalizedStoragePath(_ reference: String) -> String {
        var path = reference
        if path.hasPrefix("profile-photos/") {
            path = String(path.dropFirst("profile-photos/".count))
        }
        return path
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
