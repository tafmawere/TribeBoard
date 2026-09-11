import Foundation

enum SettingsHouseholdIntelligence {
    struct FamilyStatus {
        let statusText: String
        let subtitle: String
    }

    struct HeroConnection {
        let headline: String
        let lastActiveText: String
        let stateLabel: String
        let isAllGood: Bool
    }

    static func familyStatus(
        activeRuns: [SystemDomain.RunInstance],
        alertCount: Int,
        upcomingRunTitle: String?
    ) -> FamilyStatus {
        if !activeRuns.isEmpty {
            let runLabel = activeRuns.count == 1 ? "1 active run" : "\(activeRuns.count) active runs"
            let alertSuffix = alertCount > 0
                ? " • \(alertCount) \(alertCount == 1 ? "alert" : "alerts")"
                : ""
            let primary = activeRuns.first
            let subtitle = trimmed(primary?.title)
                ?? primary?.stopSnapshots.last?.name
                ?? "Run in progress"
            return FamilyStatus(statusText: runLabel + alertSuffix, subtitle: subtitle)
        }

        if alertCount > 0 {
            let alertLabel = alertCount == 1 ? "1 alert" : "\(alertCount) alerts"
            return FamilyStatus(
                statusText: "No active runs • \(alertLabel)",
                subtitle: "Review alerts in Runs"
            )
        }

        let subtitle: String
        if let title = trimmed(upcomingRunTitle), !title.isEmpty {
            subtitle = "\(title) ready 🚌"
        } else {
            subtitle = "School run ready 🚌"
        }

        return FamilyStatus(
            statusText: "No active runs • No alerts",
            subtitle: subtitle
        )
    }

    static func heroConnection(activeMemberCount: Int) -> HeroConnection {
        if activeMemberCount <= 1 {
            return HeroConnection(
                headline: "Invite your family to join",
                lastActiveText: "Waiting for members",
                stateLabel: "Setup needed",
                isAllGood: false
            )
        }
        return HeroConnection(
            headline: "Everyone Connected",
            lastActiveText: "Last active: Just now",
            stateLabel: "All good",
            isAllGood: true
        )
    }

    static func upcomingRunTitle(from runDataSource: RunDataSource?, now: Date = Date()) -> String? {
        guard let runDataSource else { return nil }
        let buckets = runDataSource.bucketedRuns(referenceDate: now)
        let candidate = buckets.todayRuns.first { $0.status == .scheduled }
            ?? buckets.upcomingRuns.first
            ?? buckets.todayRuns.first
        return trimmed(candidate?.title) ?? candidate?.stopSnapshots.last?.name
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
