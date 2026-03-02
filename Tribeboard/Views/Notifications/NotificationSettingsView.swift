import SwiftUI

struct NotificationSettingsView: View {
    @State private var muteAll = false

    @State private var runStartingOn = true
    @State private var driverArrivedOn = true
    @State private var runCreatedOn = true
    @State private var runCancelledOn = true

    @State private var lateAlertsOn = true
    @State private var emergencyAlertsOn = true

    @State private var pickupReminderOn = true
    @State private var dailySummaryOn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NotificationStitchCard {
                    VStack(alignment: .leading, spacing: 12) {
                        NotificationSectionHeading(
                            title: "Mute all notifications",
                            subtitle: "Pause all alerts across run updates and reminders."
                        )
                        Toggle("Mute all", isOn: $muteAll)
                            .font(.system(size: 16, weight: .semibold))
                            .tint(NotificationTheme.primary)
                    }
                }

                settingsSection(
                    title: "Run status",
                    subtitle: "Updates for trip progress and changes."
                ) {
                    NotificationToggleRow(
                        title: "Run starting",
                        subtitle: "Notify when a scheduled run is about to start.",
                        isOn: $runStartingOn
                    )
                    Divider()
                    NotificationToggleRow(
                        title: "Driver arrived",
                        subtitle: "Notify when the driver reaches pickup.",
                        isOn: $driverArrivedOn
                    )
                    Divider()
                    NotificationToggleRow(
                        title: "Run created",
                        subtitle: "Notify when a new run is added to your calendar.",
                        isOn: $runCreatedOn
                    )
                    Divider()
                    NotificationToggleRow(
                        title: "Run cancelled",
                        subtitle: "Notify when a planned run is cancelled.",
                        isOn: $runCancelledOn
                    )
                }

                settingsSection(
                    title: "Safety",
                    subtitle: "Critical events and delays."
                ) {
                    NotificationToggleRow(
                        title: "Late alerts",
                        subtitle: "Notify when ETA shifts beyond expected windows.",
                        isOn: $lateAlertsOn
                    )
                    Divider()
                    NotificationToggleRow(
                        title: "Emergency alerts",
                        subtitle: "Always show high-priority safety updates.",
                        isOn: $emergencyAlertsOn
                    )
                }

                settingsSection(
                    title: "Reminders",
                    subtitle: "Optional prompts to keep everyone on time."
                ) {
                    NotificationToggleRow(
                        title: "Pickup reminder",
                        subtitle: "Send a reminder before each pickup.",
                        isOn: $pickupReminderOn
                    )
                    Divider()
                    NotificationToggleRow(
                        title: "Daily summary",
                        subtitle: "Receive a quick recap at the end of day.",
                        isOn: $dailySummaryOn
                    )
                }
            }
            .padding(16)
        }
        .background(NotificationTheme.background.ignoresSafeArea())
        .navigationTitle("Notification Settings")
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder rows: () -> Content
    ) -> some View {
        NotificationStitchCard {
            VStack(alignment: .leading, spacing: 14) {
                NotificationSectionHeading(title: title, subtitle: subtitle)
                rows()
            }
            .disabled(muteAll)
            .opacity(muteAll ? 0.55 : 1)
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
