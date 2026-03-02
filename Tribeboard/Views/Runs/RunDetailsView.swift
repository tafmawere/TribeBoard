import SwiftUI

enum RunDetailsData {
    enum EventSeverity: Hashable {
        case normal
        case warn
        case success
    }

    struct UIStop: Identifiable, Hashable {
        let id: UUID
        var type: String
        var label: String
        var address: String
        var timeEstimate: String

        init(id: UUID = UUID(), type: String, label: String, address: String, timeEstimate: String) {
            self.id = id
            self.type = type
            self.label = label
            self.address = address
            self.timeEstimate = timeEstimate
        }
    }

    struct UITimelineEvent: Identifiable, Hashable {
        let id: UUID
        var time: Date
        var title: String
        var detail: String
        var iconName: String
        var severity: EventSeverity

        var timeString: String {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f.string(from: time)
        }

        init(
            id: UUID = UUID(),
            time: Date,
            title: String,
            detail: String,
            iconName: String,
            severity: EventSeverity
        ) {
            self.id = id
            self.time = time
            self.title = title
            self.detail = detail
            self.iconName = iconName
            self.severity = severity
        }
    }

    struct UIRun: Identifiable, Hashable {
        let id: UUID
        var title: String
        var scheduledTime: Date
        var status: String
        var driverName: String
        var passengerNames: [String]
        var passengerStatuses: [String]
        var stops: [UIStop]
        var timeline: [UITimelineEvent]
        var canEdit: Bool
        var canCancel: Bool
        var isHistory: Bool

        init(
            id: UUID = UUID(),
            title: String,
            scheduledTime: Date,
            status: String,
            driverName: String,
            passengerNames: [String],
            passengerStatuses: [String],
            stops: [UIStop],
            timeline: [UITimelineEvent],
            canEdit: Bool,
            canCancel: Bool,
            isHistory: Bool
        ) {
            self.id = id
            self.title = title
            self.scheduledTime = scheduledTime
            self.status = status
            self.driverName = driverName
            self.passengerNames = passengerNames
            self.passengerStatuses = passengerStatuses
            self.stops = stops
            self.timeline = timeline
            self.canEdit = canEdit
            self.canCancel = canCancel
            self.isHistory = isHistory
        }
    }

    static var scheduledRun: UIRun {
        UIRun(
            title: "School Dropoff",
            scheduledTime: Date().addingTimeInterval(3600),
            status: "Scheduled",
            driverName: "Tafadzwa",
            passengerNames: ["TJ", "Tawana"],
            passengerStatuses: ["Waiting", "Waiting"],
            stops: [
                .init(type: "Pickup", label: "Home", address: "123 Maple St", timeEstimate: "06:45"),
                .init(type: "Dropoff", label: "Lincoln Elementary", address: "456 School Ave", timeEstimate: "07:05")
            ],
            timeline: [
                .init(time: Date().addingTimeInterval(-1800), title: "Scheduled", detail: "Run created by Rue", iconName: "calendar", severity: .normal),
                .init(time: Date().addingTimeInterval(-1200), title: "Reminder sent", detail: "Family notified", iconName: "bell", severity: .normal)
            ],
            canEdit: true,
            canCancel: true,
            isHistory: false
        )
    }

    static var completedRun: UIRun {
        UIRun(
            title: "School Pickup",
            scheduledTime: Date().addingTimeInterval(-86400),
            status: "Completed",
            driverName: "Tafadzwa",
            passengerNames: ["TJ", "Tawana"],
            passengerStatuses: ["Dropped", "Dropped"],
            stops: [
                .init(type: "Pickup", label: "Lincoln Elementary", address: "456 School Ave", timeEstimate: "14:30"),
                .init(type: "Dropoff", label: "Home", address: "123 Maple St", timeEstimate: "14:55")
            ],
            timeline: [
                .init(time: Date().addingTimeInterval(-86000), title: "Scheduled", detail: "Template applied", iconName: "calendar", severity: .normal),
                .init(time: Date().addingTimeInterval(-84000), title: "Started", detail: "Driver began run", iconName: "play.fill", severity: .normal),
                .init(time: Date().addingTimeInterval(-81000), title: "Completed", detail: "All passengers dropped", iconName: "checkmark.circle.fill", severity: .success)
            ],
            canEdit: false,
            canCancel: false,
            isHistory: true
        )
    }
}

struct RunDetailsView: View {
    @State private var run: RunDetailsData.UIRun
    @State private var showCancelSheet = false
    @State private var showCancelledBanner = false
    @State private var cancellationReason = ""

    init(run: RunDetailsData.UIRun = RunDetailsData.scheduledRun) {
        _run = State(initialValue: run)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if showCancelledBanner {
                    StatusBadge(
                        text: "Run cancelled\(cancellationReason.isEmpty ? "" : " • \(cancellationReason)")",
                        color: RunStitchTheme.warning
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                headerCard
                routeCard
                passengersCard
                timelineCard
                actionsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(RunStitchTheme.background.ignoresSafeArea())
        .navigationTitle("Run Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCancelSheet) {
            CancelRunConfirmView { selectedReason in
                cancellationReason = selectedReason
                showCancelledBanner = true
            }
        }
    }

    private var headerCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(run.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(RunStitchTheme.textPrimary)
                    Spacer()
                    StatusBadge(text: run.status, color: statusColor(run.status))
                }
                Text(formattedDate(run.scheduledTime))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(RunStitchTheme.textSecondary)

                Text("Driver: \(run.driverName)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(RunStitchTheme.textSecondary)

                HStack(spacing: 6) {
                    ForEach(run.passengerNames, id: \.self) { name in
                        RoleChip(text: initials(name), color: RunStitchTheme.indigo)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var routeCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Route")
                ForEach(Array(run.stops.enumerated()), id: \.element.id) { idx, stop in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Text("\(idx + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(stop.type == "Pickup" ? RunStitchTheme.indigo : RunStitchTheme.success)
                                .clipShape(Circle())
                            if idx < run.stops.count - 1 {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.30))
                                    .frame(width: 2, height: 20)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            RoleChip(text: stop.type, color: stop.type == "Pickup" ? RunStitchTheme.indigo : RunStitchTheme.success)
                            Text(stop.label)
                                .font(.system(size: 15, weight: .semibold))
                            Text(stop.address)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(RunStitchTheme.textSecondary)
                        }
                        Spacer()
                        Text(stop.timeEstimate)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RunStitchTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var passengersCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Passengers")
                ForEach(Array(run.passengerNames.enumerated()), id: \.offset) { idx, name in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(RunStitchTheme.indigo.opacity(0.14))
                            .frame(width: 34, height: 34)
                            .overlay {
                                Text(initials(name))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(RunStitchTheme.indigo)
                            }
                        Text(name)
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text(idx < run.passengerStatuses.count ? run.passengerStatuses[idx] : "Waiting")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RunStitchTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var timelineCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Timeline")
                ForEach(Array(run.timeline.enumerated()), id: \.element.id) { idx, event in
                    TimelineRow(event: event, isLast: idx == run.timeline.count - 1)
                }
            }
        }
    }

    private var actionsCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Actions")
                PrimaryButton(title: "Track Run") {
                    print("Track Run tapped")
                }
                SecondaryButton(title: "Share Status") {
                    print("Share Status tapped")
                }
                SecondaryButton(title: "Call Driver") {
                    if let url = URL(string: "tel://+1234567890"), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        print("Call Driver tapped")
                    }
                }

                if run.canEdit {
                    NavigationLink {
                        RunEditRescheduleView(run: run) { updated in
                            run = updated
                        }
                    } label: {
                        SecondaryButton(title: "Edit / Reschedule") {}
                    }
                    .buttonStyle(.plain)
                }

                if run.canCancel {
                    DestructiveButton(title: "Cancel Run") {
                        showCancelSheet = true
                    }
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM • h:mm a"
        return formatter.string(from: date)
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "scheduled":
            return RunStitchTheme.warning
        case "active":
            return RunStitchTheme.indigo
        case "completed":
            return RunStitchTheme.success
        default:
            return RunStitchTheme.textSecondary
        }
    }
}

struct RunScreensPreviewRootView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Open Scheduled Run Details") {
                    RunDetailsView(run: RunDetailsData.scheduledRun)
                }
                NavigationLink("Open History Example") {
                    RunHistoryDetailView(run: RunDetailsData.completedRun)
                }
            }
            .navigationTitle("Run Screens")
        }
    }
}

#Preview {
    RunScreensPreviewRootView()
}
