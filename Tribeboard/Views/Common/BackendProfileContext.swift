import Foundation
import Combine

@MainActor
final class BackendProfileContext: ObservableObject {
    @Published var currentUserProfile: BackendProfile?
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    private let service: ProfileBackendService

    init(service: ProfileBackendService? = nil) {
        self.service = service ?? SupabaseProfileBackendService()
    }

    func refreshProfile(authEmail: String? = nil, providerDisplayName: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        let authUserId = try? await service.currentAuthUserId()
#if DEBUG
        print("[BackendProfileContext] PROFILE FETCH START auth.uid=\(authUserId?.uuidString ?? "unknown")")
#endif
        do {
            let fetched = try await service.fetchMyProfile()
            if let fetched, let authUserId, fetched.id != authUserId {
#if DEBUG
                print(
                    "[BackendProfileContext] PROFILE USER MISMATCH auth.uid=\(authUserId.uuidString), " +
                    "profile.id=\(fetched.id.uuidString)"
                )
#endif
                await MainActor.run {
                    currentUserProfile = nil
                    lastError = "Profile user mismatch."
                }
                return
            }
            await MainActor.run {
                currentUserProfile = fetched
            }
#if DEBUG
            if let loaded = currentUserProfile {
                print(
                    "[BackendProfileContext] PROFILE FETCH RESULT auth.uid=\(authUserId?.uuidString ?? "unknown"), " +
                    "auth.email=\(authEmail ?? "nil"), provider_name=\(providerDisplayName ?? "nil"), " +
                    "profile.id=\(loaded.id.uuidString), display_name=\(loaded.display_name ?? "nil"), " +
                    "first_name=\(loaded.first_name ?? "nil"), last_name=\(loaded.last_name ?? "nil"), avatar_url=\(loaded.avatar_url ?? "nil")"
                )
            } else {
                print(
                    "[BackendProfileContext] PROFILE NOT FOUND FOR USER auth.uid=\(authUserId?.uuidString ?? "unknown"), " +
                    "auth.email=\(authEmail ?? "nil"), provider_name=\(providerDisplayName ?? "nil")"
                )
            }
#endif
            lastError = nil
        } catch {
            if isCancellationError(error) {
#if DEBUG
                print("[BackendProfileContext] ignored cancellation during profile refresh")
#endif
                return
            }
            await MainActor.run {
                currentUserProfile = nil
                lastError = error.localizedDescription
            }
#if DEBUG
            print(
                "[BackendProfileContext] PROFILE FETCH FAILED auth.uid=\(authUserId?.uuidString ?? "unknown"), " +
                "error=\(error.localizedDescription)"
            )
#endif
        }
    }

    func ensureProfileExists(email: String?, providerDisplayName: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        let authUserId = try? await service.currentAuthUserId()
#if DEBUG
        print("[BackendProfileContext] PROFILE ENSURE START auth.uid=\(authUserId?.uuidString ?? "unknown")")
#endif
        do {
            let existing = try await service.fetchMyProfile()
            if existing == nil {
                try await service.upsertMyProfile(
                    email: email,
                    displayName: providerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    firstName: nil,
                    lastName: nil,
                    avatarURL: nil
                )
            } else if existing?.display_name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty == nil,
                      let providerDisplayName = providerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                try await service.upsertMyProfile(
                    email: existing?.email ?? email,
                    displayName: providerDisplayName,
                    firstName: existing?.first_name,
                    lastName: existing?.last_name,
                    avatarURL: existing?.avatar_url
                )
            }
            let fetched = try await service.fetchMyProfile()
            if let fetched, let authUserId, fetched.id != authUserId {
#if DEBUG
                print(
                    "[BackendProfileContext] PROFILE USER MISMATCH auth.uid=\(authUserId.uuidString), " +
                    "profile.id=\(fetched.id.uuidString)"
                )
#endif
                await MainActor.run {
                    currentUserProfile = nil
                    lastError = "Profile user mismatch."
                }
                return
            }
            await MainActor.run {
                currentUserProfile = fetched
            }
#if DEBUG
            if let loaded = currentUserProfile {
                print(
                    "[BackendProfileContext] PROFILE ENSURE RESULT auth.uid=\(authUserId?.uuidString ?? "unknown"), " +
                    "auth.email=\(email ?? "nil"), provider_name=\(providerDisplayName ?? "nil"), " +
                    "profile.id=\(loaded.id.uuidString), display_name=\(loaded.display_name ?? "nil"), " +
                    "first_name=\(loaded.first_name ?? "nil"), last_name=\(loaded.last_name ?? "nil"), avatar_url=\(loaded.avatar_url ?? "nil")"
                )
            } else {
                print(
                    "[BackendProfileContext] PROFILE NOT FOUND FOR USER auth.uid=\(authUserId?.uuidString ?? "unknown"), " +
                    "auth.email=\(email ?? "nil"), provider_name=\(providerDisplayName ?? "nil")"
                )
            }
#endif
            lastError = nil
        } catch {
            if isCancellationError(error) {
#if DEBUG
                print("[BackendProfileContext] ignored cancellation during profile refresh")
#endif
                return
            }
            await MainActor.run {
                currentUserProfile = nil
                lastError = error.localizedDescription
            }
#if DEBUG
            print(
                "[BackendProfileContext] PROFILE ENSURE FAILED auth.uid=\(authUserId?.uuidString ?? "unknown"), " +
                "error=\(error.localizedDescription)"
            )
#endif
        }
    }
    
    func reset() {
        currentUserProfile = nil
        isLoading = false
        lastError = nil
    }

    func updateCurrentUserProfile(
        firstName: String,
        lastName: String,
        displayName: String,
        avatarURL: String?,
        authEmail: String?,
        providerDisplayName: String?
    ) async -> Bool {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplay = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = currentUserProfile
        let existingFirst = existing?.first_name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let existingLast = existing?.last_name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let existingDisplay = existing?.display_name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let existingAvatar = existing?.avatar_url?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        let resolvedFirst = trimmedFirst.isEmpty ? existingFirst : trimmedFirst
        let resolvedLast = trimmedLast.isEmpty ? existingLast : trimmedLast
        let composedFromNames = [resolvedFirst, resolvedLast]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let candidateDisplayName: String? = {
            if !trimmedDisplay.isEmpty { return trimmedDisplay }
            if !composedFromNames.isEmpty { return composedFromNames }
            return nil
        }()

        guard candidateDisplayName != nil || !trimmedFirst.isEmpty || !trimmedLast.isEmpty else {
            lastError = "Please provide at least one name field."
            return false
        }

        let finalDisplayName = candidateDisplayName ?? existingDisplay
        let finalAvatarURL = avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? existingAvatar
        let emailForUpsert = existing?.email ?? authEmail
        let authUserId = try? await service.currentAuthUserId()
#if DEBUG
        print(
            "[BackendProfileContext] profile save auth.uid=\(authUserId?.uuidString ?? "unknown"), " +
            "old_display_name=\(existingDisplay ?? "nil"), new_display_name=\(finalDisplayName ?? "nil"), " +
            "old_first_name=\(existingFirst ?? "nil"), new_first_name=\(resolvedFirst ?? "nil"), " +
            "old_last_name=\(existingLast ?? "nil"), new_last_name=\(resolvedLast ?? "nil"), " +
            "old_avatar_url=\(existingAvatar ?? "nil"), new_avatar_url=\(finalAvatarURL ?? "nil")"
        )
#endif

        isLoading = true
        defer { isLoading = false }
        do {
            var patchFields: [String: String?] = [:]
            if resolvedFirst != existingFirst {
                patchFields["first_name"] = resolvedFirst
            }
            if resolvedLast != existingLast {
                patchFields["last_name"] = resolvedLast
            }
            if finalDisplayName != existingDisplay {
                patchFields["display_name"] = finalDisplayName
            }
            if finalAvatarURL != existingAvatar {
                patchFields["avatar_url"] = finalAvatarURL
            }
            if existing?.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty == nil,
               let emailForUpsert = emailForUpsert?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                patchFields["email"] = emailForUpsert
            }
            try await service.patchMyProfile(fields: patchFields)
            await refreshProfile(authEmail: authEmail, providerDisplayName: providerDisplayName)
#if DEBUG
            print(
                "[BackendProfileContext] profile save success auth.uid=\(authUserId?.uuidString ?? "unknown"), " +
                "saved_display_name=\(currentUserProfile?.display_name ?? "nil"), " +
                "saved_first_name=\(currentUserProfile?.first_name ?? "nil"), " +
                "saved_last_name=\(currentUserProfile?.last_name ?? "nil"), " +
                "saved_avatar_url=\(currentUserProfile?.avatar_url ?? "nil")"
            )
#endif
            lastError = nil
            return true
        } catch {
            if isCancellationError(error) {
#if DEBUG
                print("[BackendProfileContext] ignored cancellation during profile save")
#endif
                return false
            }
            lastError = error.localizedDescription
#if DEBUG
            print(
                "[BackendProfileContext] profile save failed auth.uid=\(authUserId?.uuidString ?? "unknown"), " +
                "error=\(error.localizedDescription)"
            )
#endif
            return false
        }
    }

    // Backward-compatible alias for existing views.
    var profile: BackendProfile? {
        currentUserProfile
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
