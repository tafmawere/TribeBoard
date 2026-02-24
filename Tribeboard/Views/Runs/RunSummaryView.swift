import SwiftUI
import MapKit
import CoreLocation

struct RunSummaryView: View {
    let run: UIRun
    let routeCoordinates: [CLLocationCoordinate2D]
    let completionDate: Date

    @State private var mapPosition: MapCameraPosition

    init(run: UIRun, routeCoordinates: [CLLocationCoordinate2D], completionDate: Date) {
        self.run = run
        self.routeCoordinates = routeCoordinates
        self.completionDate = completionDate

        let center = routeCoordinates.isEmpty
            ? CLLocationCoordinate2D(latitude: 37.7818, longitude: -122.4154)
            : routeCoordinates[routeCoordinates.count / 2]
        _mapPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.020, longitudeDelta: 0.020)
            )
        ))
    }

    private var startCoordinate: CLLocationCoordinate2D {
        routeCoordinates.first ?? CLLocationCoordinate2D(latitude: 37.7768, longitude: -122.4236)
    }

    private var endCoordinate: CLLocationCoordinate2D {
        routeCoordinates.last ?? CLLocationCoordinate2D(latitude: 37.7870, longitude: -122.4095)
    }

    private var totalDistanceText: String {
        String(format: "%.1f mi", routeDistanceMiles())
    }

    private var totalDurationText: String {
        let duration = max(16, routeCoordinates.count * 3)
        return "\(duration) min"
    }

    private var completionTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: completionDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard
                mapPreviewCard
                timelineCard
                safetySummaryCard
                bottomButtons
            }
            .padding(16)
        }
        .background(UIRunDesignSystem.background.ignoresSafeArea())
        .navigationTitle("Run Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text(run.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)

                HStack(spacing: 10) {
                    summaryMetric(label: "Completed", value: completionTimeText)
                    summaryMetric(label: "Duration", value: totalDurationText)
                    summaryMetric(label: "Distance", value: totalDistanceText)
                }
            }
        }
    }

    private var mapPreviewCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Route Preview")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)

                Map(position: $mapPosition, interactionModes: .all) {
                    Marker("Start", coordinate: startCoordinate)
                        .tint(UIRunDesignSystem.success)

                    Marker("End", coordinate: endCoordinate)
                        .tint(.red)

                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(UIRunDesignSystem.primary.opacity(0.85), lineWidth: 5)
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                UISecondaryButton(title: "Replay Route", icon: "arrow.clockwise") {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        mapPosition = .region(
                            MKCoordinateRegion(
                                center: startCoordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.020, longitudeDelta: 0.020)
                            )
                        )
                    }
                }
            }
        }
    }

    private var timelineCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Timeline")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)

                ForEach(timelineEvents.indices, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(UIRunDesignSystem.primary.opacity(0.22))
                            .frame(width: 9, height: 9)
                            .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(timelineEvents[idx].title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                                Spacer()
                                Text(timelineEvents[idx].time)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                            }
                            Text(timelineEvents[idx].subtitle)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var safetySummaryCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Safety Summary")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)

                safetyRow(label: "Average speed", value: "28 mph")
                safetyRow(label: "Route deviations", value: "None (placeholder)")
                safetyRow(label: "Location sharing", value: totalDurationText)
            }
        }
    }

    private var bottomButtons: some View {
        VStack(spacing: 8) {
            UIPrimaryButton(title: "Share Summary", icon: "square.and.arrow.up") {
                print("Share summary placeholder")
            }
            UISecondaryButton(title: "Done", icon: "checkmark.circle") {
                print("Done placeholder")
            }
        }
    }

    private var timelineEvents: [(title: String, subtitle: String, time: String)] {
        [
            ("Left origin", "Departed start point", shiftedTime(mins: -24)),
            ("Arrived at pickup", "Driver reached pickup zone", shiftedTime(mins: -18)),
            ("Picked up passengers", "All expected passengers onboard", shiftedTime(mins: -15)),
            ("Arrived at drop-off", "Reached destination stop", shiftedTime(mins: -4)),
            ("Completed run", "Run marked complete", shiftedTime(mins: 0))
        ]
    }

    private func summaryMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(UIRunDesignSystem.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.70))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func safetyRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(UIRunDesignSystem.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)
        }
    }

    private func shiftedTime(mins: Int) -> String {
        let date = Calendar.current.date(byAdding: .minute, value: mins, to: completionDate) ?? completionDate
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func routeDistanceMiles() -> Double {
        guard routeCoordinates.count > 1 else { return 0 }
        var meters: CLLocationDistance = 0
        for idx in 0..<(routeCoordinates.count - 1) {
            let start = CLLocation(latitude: routeCoordinates[idx].latitude, longitude: routeCoordinates[idx].longitude)
            let end = CLLocation(latitude: routeCoordinates[idx + 1].latitude, longitude: routeCoordinates[idx + 1].longitude)
            meters += start.distance(from: end)
        }
        return meters / 1609.34
    }
}

#Preview {
    NavigationStack {
        RunSummaryView(
            run: UIRunMockData.activeRun,
            routeCoordinates: [
                CLLocationCoordinate2D(latitude: 37.7768, longitude: -122.4236),
                CLLocationCoordinate2D(latitude: 37.7818, longitude: -122.4154),
                CLLocationCoordinate2D(latitude: 37.7870, longitude: -122.4095)
            ],
            completionDate: Date()
        )
    }
}
