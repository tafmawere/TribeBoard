import EventKit
import Foundation

enum CalendarAuthState: String {
    case notDetermined = "Not Determined"
    case denied = "Denied"
    case restricted = "Restricted"
    case authorized = "Authorized"
}

typealias CalendarSyncPermissionStatus = CalendarAuthState

enum CalendarSyncServiceError: LocalizedError {
    case accessDenied
    case restricted
    case missingCalendar
    case unableToCreateCalendar

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access is denied. Enable access in Settings to continue."
        case .restricted:
            return "Calendar access is restricted on this device."
        case .missingCalendar:
            return "Select a calendar before syncing."
        case .unableToCreateCalendar:
            return "Unable to create the TribeBoard calendar."
        }
    }
}

@MainActor
final class CalendarSyncService {
    static let dedicatedCalendarTitle = "TribeBoard"
    static let selectedCalendarIdentifierDefaultsKey = "calendar_sync_selected_calendar_identifier"

    private let eventStore = EKEventStore()

    func authorizationState() -> CalendarAuthState {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .authorized, .fullAccess, .writeOnly:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }

    // Backward-compatible alias for existing callers.
    func permissionStatus() -> CalendarSyncPermissionStatus {
        authorizationState()
    }

    func requestCalendarAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                return false
            }
        }
        return await requestCalendarAccessLegacy()
    }

    @available(iOS, introduced: 13.0, deprecated: 17.0)
    private func requestCalendarAccessLegacy() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            eventStore.requestAccess(to: .event) { accessGranted, _ in
                continuation.resume(returning: accessGranted)
            }
        }
    }

    func syncNow(using calendar: EKCalendar?) async throws -> Int {
        let status = authorizationState()
        switch status {
        case .restricted:
            throw CalendarSyncServiceError.restricted
        case .denied, .notDetermined:
            throw CalendarSyncServiceError.accessDenied
        case .authorized:
            break
        }

        guard calendar != nil else {
            throw CalendarSyncServiceError.missingCalendar
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task {
                try? await Task.sleep(nanoseconds: 120_000_000)
                continuation.resume(returning: ())
            }
        }
        return 0
    }

    func writableCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event).filter(\.allowsContentModifications)
    }

    func tribeBoardCalendar() -> EKCalendar? {
        writableCalendars().first { $0.title.caseInsensitiveCompare(Self.dedicatedCalendarTitle) == .orderedSame }
    }

    func calendar(for identifier: String?) -> EKCalendar? {
        guard let identifier, !identifier.isEmpty else { return nil }
        return eventStore.calendar(withIdentifier: identifier)
    }

    func createTribeBoardCalendar() throws -> EKCalendar {
        if let existing = tribeBoardCalendar() {
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = Self.dedicatedCalendarTitle

        if let source = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if let fallbackSource = preferredSource() {
            calendar.source = fallbackSource
        } else {
            throw CalendarSyncServiceError.unableToCreateCalendar
        }

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            throw CalendarSyncServiceError.unableToCreateCalendar
        }
    }


    private func preferredSource() -> EKSource? {
        let sources = eventStore.sources
        return sources.first(where: { $0.sourceType == .calDAV })
            ?? sources.first(where: { $0.sourceType == .exchange })
            ?? sources.first(where: { $0.sourceType == .local })
            ?? sources.first
    }
}
