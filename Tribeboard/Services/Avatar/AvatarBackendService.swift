import Foundation
import UIKit

struct AvatarPatchPayload: Encodable {
    let avatar_type: String
    let avatar_key: String?
    let avatar_url: String?
    let avatar_updated_at: String
}

protocol AvatarBackendServiceProtocol {
    func uploadProfilePhoto(profileId: UUID, imageData: Data, accessToken: String) async throws -> String
    func createSignedURL(storagePath: String, accessToken: String, expiresIn: Int) async -> URL?
    func patchProfileAvatar(profileId: UUID, patch: AvatarPatchPayload, accessToken: String) async throws
    func patchChildAvatar(childId: UUID, patch: AvatarPatchPayload, accessToken: String) async throws
}

struct AvatarBackendService: AvatarBackendServiceProtocol {
    enum ServiceError: LocalizedError {
        case uploadFailed(String)
        case signFailed(String)

        var errorDescription: String? {
            switch self {
            case .uploadFailed(let message), .signFailed(let message):
                return message
            }
        }
    }

    private struct SignRequest: Encodable {
        let expiresIn: Int
    }

    private struct SignResponse: Decodable {
        let signedURL: String?

        enum CodingKeys: String, CodingKey {
            case signedURL = "signedURL"
        }
    }

    func uploadProfilePhoto(profileId: UUID, imageData: Data, accessToken: String) async throws -> String {
        let objectPath = AvatarURLResolver.storagePath(profileId: profileId)
        let url = try storageObjectURL(bucket: "profile-photos", objectPath: objectPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        var headers = try SupabaseClientProvider.authenticatedHeaders(accessToken: accessToken)
        headers["Content-Type"] = "image/jpeg"
        headers["x-upsert"] = "true"
        request.allHTTPHeaderFields = headers
        request.httpBody = imageData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown upload error."
            throw ServiceError.uploadFailed(body)
        }
        return "profile-photos/\(objectPath)"
    }

    func createSignedURL(storagePath: String, accessToken: String, expiresIn: Int = 3600) async -> URL? {
        do {
            let url = try storageSignURL(bucket: "profile-photos", objectPath: storagePath)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            var headers = try SupabaseClientProvider.authenticatedHeaders(accessToken: accessToken)
            headers["Content-Type"] = "application/json"
            request.allHTTPHeaderFields = headers
            request.httpBody = try JSONEncoder().encode(SignRequest(expiresIn: expiresIn))

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }

            if let decoded = try? JSONDecoder().decode(SignResponse.self, from: data),
               let signed = decoded.signedURL,
               let signedURL = URL(string: signed) {
                return signedURL
            }

            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let signed = object["signedURL"] as? String ?? object["signedUrl"] as? String,
               let signedURL = URL(string: signed) {
                return signedURL
            }

            if let signed = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty,
               signed.hasPrefix("http"),
               let signedURL = URL(string: signed) {
                return signedURL
            }
            return nil
        } catch {
            return nil
        }
    }

    func patchProfileAvatar(profileId: UUID, patch payload: AvatarPatchPayload, accessToken: String) async throws {
        let path = "profiles?id=eq.\(profileId.uuidString)"
        _ = try await patch(path: path, payload: payload, accessToken: accessToken) as [BackendProfile]
    }

    func patchChildAvatar(childId: UUID, patch payload: AvatarPatchPayload, accessToken: String) async throws {
        let path = "children?id=eq.\(childId.uuidString)"
        _ = try await patch(path: path, payload: payload, accessToken: accessToken) as [BackendChild]
    }

    static func makePatch(
        avatarType: AvatarType,
        avatarKey: String?,
        avatarURL: String?
    ) -> AvatarPatchPayload {
        AvatarPatchPayload(
            avatar_type: avatarType.rawValue,
            avatar_key: avatarType == .preset ? avatarKey : nil,
            avatar_url: avatarType == .uploaded ? avatarURL : nil,
            avatar_updated_at: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func storageObjectURL(bucket: String, objectPath: String) throws -> URL {
        let config = try SupabaseClientProvider.configuration()
        var components = URLComponents(
            url: config.projectURL
                .appendingPathComponent("storage")
                .appendingPathComponent("v1")
                .appendingPathComponent("object")
                .appendingPathComponent(bucket)
                .appendingPathComponent(objectPath),
            resolvingAgainstBaseURL: false
        )
        guard let url = components?.url else {
            throw SupabaseClientProvider.ProviderError.invalidURL
        }
        return url
    }

    private func storageSignURL(bucket: String, objectPath: String) throws -> URL {
        let config = try SupabaseClientProvider.configuration()
        let url = config.projectURL
            .appendingPathComponent("storage")
            .appendingPathComponent("v1")
            .appendingPathComponent("object")
            .appendingPathComponent("sign")
            .appendingPathComponent(bucket)
            .appendingPathComponent(objectPath)
        return url
    }

    private func patch<T: Decodable, P: Encodable>(path: String, payload: P, accessToken: String) async throws -> T {
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        var headers = try SupabaseClientProvider.authenticatedHeaders(accessToken: accessToken)
        headers["Prefer"] = "return=representation"
        request.allHTTPHeaderFields = headers
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error."
            throw ServiceError.uploadFailed(body)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
