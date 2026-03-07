import Foundation
import Combine
import UserNotifications

enum NotificationAuthorizationState: String {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

struct NotificationRequest: Equatable {
    let id: String
    let title: String
    let body: String
    let triggerDate: Date
}

@MainActor
final class NotificationService: ObservableObject {
    @Published private(set) var authorizationState: NotificationAuthorizationState = .notDetermined
    @Published private(set) var lastError: String?

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func refreshAuthorizationState() async {
        let settings = await notificationSettings()
        authorizationState = Self.mapAuthorization(settings.authorizationStatus)
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationState()
            if !granted {
                lastError = "Notifications permission was not granted."
            } else {
                lastError = nil
            }
            return granted
        } catch {
            lastError = "Unable to request notifications permission."
            return false
        }
    }

    func schedule(_ request: NotificationRequest) async {
        if request.triggerDate <= Date() {
            return
        }
        await refreshAuthorizationState()
        guard isAuthorizedState(authorizationState) else {
            lastError = "Notifications are not authorized."
            return
        }

        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: request.triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let notificationRequest = UNNotificationRequest(
            identifier: request.id,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(notificationRequest)
            lastError = nil
        } catch {
            lastError = "Unable to schedule notification."
        }
    }

    func removePending(withIDs ids: [String]) async {
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func removeAllPending() async {
        center.removeAllPendingNotificationRequests()
    }

    func pendingRequestIDs() async -> [String] {
        let requests = await center.pendingNotificationRequests()
        return requests.map(\.identifier).sorted()
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func isAuthorizedState(_ state: NotificationAuthorizationState) -> Bool {
        state == .authorized || state == .provisional || state == .ephemeral
    }

    private static func mapAuthorization(_ status: UNAuthorizationStatus) -> NotificationAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .notDetermined
        }
    }
}
