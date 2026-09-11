import Foundation

struct RunDriverIdentity: Equatable {
    let driverId: UUID?
    let displayName: String
    let avatar: TribeAvatarIdentity
    let role: String
}

enum RunDriverIdentityResolver {
    static func resolve(
        run: SystemDomain.RunInstance,
        drivers: [BackendDriver],
        profilesByUserId: [UUID: BackendProfile]
    ) -> RunDriverIdentity {
        let driverId = run.assignedDriverId ?? run.driverId

        if let driverId,
           let driver = drivers.first(where: { $0.id == driverId }) {
            let avatar: TribeAvatarIdentity
            if let userId = driver.userId, let profile = profilesByUserId[userId] {
                avatar = profile.avatarIdentity(fallbackDisplayName: driver.displayName)
            } else {
                avatar = TribeAvatarIdentity(displayName: driver.displayName)
            }
            return RunDriverIdentity(
                driverId: driverId,
                displayName: driver.displayName,
                avatar: avatar,
                role: driver.role
            )
        }

        let fallbackName = run.assignedDriverName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? "Driver"
        return RunDriverIdentity(
            driverId: driverId,
            displayName: fallbackName,
            avatar: TribeAvatarIdentity(displayName: fallbackName),
            role: "driver"
        )
    }

    static func resolve(
        run: SystemDomain.RunInstance,
        backendDriversContext: BackendDriversContext,
        profilesByUserId: [UUID: BackendProfile]
    ) -> RunDriverIdentity {
        resolve(run: run, drivers: backendDriversContext.drivers, profilesByUserId: profilesByUserId)
    }

    static func isCurrentUserDriver(
        run: SystemDomain.RunInstance,
        drivers: [BackendDriver],
        currentUserId: UUID?
    ) -> Bool {
        guard let currentUserId else { return false }
        guard let driverId = run.assignedDriverId ?? run.driverId else { return false }
        if driverId == currentUserId { return true }
        if let driver = drivers.first(where: { $0.id == driverId }),
           driver.userId == currentUserId {
            return true
        }
        return false
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
