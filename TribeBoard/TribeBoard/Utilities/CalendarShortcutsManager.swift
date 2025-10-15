import SwiftUI
import Foundation
import Intents

/// Manager for calendar shortcuts and quick actions
@MainActor
class CalendarShortcutsManager: ObservableObject {
    static let shared = CalendarShortcutsManager()
    
    @Published var availableShortcuts: [CalendarShortcut] = []
    
    private let calendarService: CalendarService
    
    private init() {
        self.calendarService = CalendarService()
        setupShortcuts()
    }
    
    // MARK: - Shortcut Setup
    
    private func setupShortcuts() {
        availableShortcuts = [
            CalendarShortcut(
                id: "create_event",
                title: "Create Event",
                subtitle: "Add a new calendar event",
                icon: "plus.circle.fill",
                color: .blue,
                action: .createEvent
            ),
            CalendarShortcut(
                id: "view_today",
                title: "Today's Events",
                subtitle: "View events for today",
                icon: "calendar.badge.clock",
                color: .green,
                action: .viewToday
            ),
            CalendarShortcut(
                id: "sync_calendar",
                title: "Sync Calendar",
                subtitle: "Sync with Apple Calendar",
                icon: "arrow.clockwise.icloud",
                color: .orange,
                action: .syncCalendar
            ),
            CalendarShortcut(
                id: "family_events",
                title: "Family Events",
                subtitle: "View shared family events",
                icon: "person.2.fill",
                color: .purple,
                action: .viewFamilyEvents
            ),
            CalendarShortcut(
                id: "upcoming_events",
                title: "Upcoming Events",
                subtitle: "View upcoming events",
                icon: "calendar.badge.plus",
                color: .red,
                action: .viewUpcoming
            )
        ]
    }
    
    // MARK: - Shortcut Execution
    
    func executeShortcut(_ shortcut: CalendarShortcut) async {
        CalendarHapticManager.shared.lightImpact()
        
        switch shortcut.action {
        case .createEvent:
            await handleCreateEvent()
        case .viewToday:
            await handleViewToday()
        case .syncCalendar:
            await handleSyncCalendar()
        case .viewFamilyEvents:
            await handleViewFamilyEvents()
        case .viewUpcoming:
            await handleViewUpcoming()
        }
    }
    
    // MARK: - Shortcut Handlers
    
    private func handleCreateEvent() async {
        // This would typically trigger navigation to event creation
        NotificationCenter.default.post(
            name: .calendarShortcutTriggered,
            object: CalendarShortcutAction.createEvent
        )
    }
    
    private func handleViewToday() async {
        NotificationCenter.default.post(
            name: .calendarShortcutTriggered,
            object: CalendarShortcutAction.viewToday
        )
    }
    
    private func handleSyncCalendar() async {
        CalendarHapticManager.shared.syncInitiated()
        
        do {
            try await calendarService.syncWithAppleCalendar()
            CalendarHapticManager.shared.syncSuccess()
            
            NotificationCenter.default.post(
                name: .calendarSyncCompleted,
                object: true
            )
        } catch {
            CalendarHapticManager.shared.error()
            
            NotificationCenter.default.post(
                name: .calendarSyncCompleted,
                object: false
            )
        }
    }
    
    private func handleViewFamilyEvents() async {
        NotificationCenter.default.post(
            name: .calendarShortcutTriggered,
            object: CalendarShortcutAction.viewFamilyEvents
        )
    }
    
    private func handleViewUpcoming() async {
        NotificationCenter.default.post(
            name: .calendarShortcutTriggered,
            object: CalendarShortcutAction.viewUpcoming
        )
    }
    
    // MARK: - Quick Actions
    
    func getQuickActions() -> [CalendarQuickAction] {
        return [
            CalendarQuickAction(
                title: "Add Event",
                icon: "plus",
                action: { await self.handleCreateEvent() }
            ),
            CalendarQuickAction(
                title: "Sync Now",
                icon: "arrow.clockwise",
                action: { await self.handleSyncCalendar() }
            ),
            CalendarQuickAction(
                title: "Today",
                icon: "calendar.badge.clock",
                action: { await self.handleViewToday() }
            )
        ]
    }
}

// MARK: - Supporting Types

struct CalendarShortcut: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: CalendarShortcutAction
}

enum CalendarShortcutAction {
    case createEvent
    case viewToday
    case syncCalendar
    case viewFamilyEvents
    case viewUpcoming
}

struct CalendarQuickAction {
    let title: String
    let icon: String
    let action: () async -> Void
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let calendarShortcutTriggered = Notification.Name("calendarShortcutTriggered")
    static let calendarSyncCompleted = Notification.Name("calendarSyncCompleted")
}

// MARK: - Calendar Shortcuts View

struct CalendarShortcutsView: View {
    @StateObject private var shortcutsManager = CalendarShortcutsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar Shortcuts")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(shortcutsManager.availableShortcuts) { shortcut in
                    CalendarShortcutCard(shortcut: shortcut) {
                        Task {
                            await shortcutsManager.executeShortcut(shortcut)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct CalendarShortcutCard: View {
    let shortcut: CalendarShortcut
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: shortcut.icon)
                    .font(.title2)
                    .foregroundColor(shortcut.color)
                
                VStack(spacing: 2) {
                    Text(shortcut.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(shortcut.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(shortcut.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(shortcut.title)
        .accessibilityHint(shortcut.subtitle)
    }
}

#Preview {
    CalendarShortcutsView()
        .previewEnvironment()
}