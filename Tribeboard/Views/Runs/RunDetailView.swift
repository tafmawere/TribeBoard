import SwiftUI
import MapKit
import CoreLocation
import Combine

private enum OperationalRunState: String, CaseIterable {
    case enRouteToPickup = "En Route to Pickup"
    case pickedUp = "Picked Up"
    case enRouteToDropOff = "En Route to Drop-off"
    case completed = "Completed"

    var stepIndex: Int {
        switch self {
        case .enRouteToPickup: return 0
        case .pickedUp: return 1
        case .enRouteToDropOff: return 2
        case .completed: return 3
        }
    }
}

private enum RunViewerRole: String {
    case driver = "driver"
    case observer = "observer"
}

struct RunDetailView: View {
    let run: UIRun

    @AppStorage("profile.activeRole") private var activeRoleRawValue = RunViewerRole.driver.rawValue

    @State private var mapPosition: MapCameraPosition
    @State private var driverCoordinate: CLLocationCoordinate2D
    @State private var liveState: OperationalRunState = .enRouteToPickup
    @State private var liveProgress: Double = 0.20
    @State private var routeStepIndex: Int = 1

    private let routeCoordinates: [CLLocationCoordinate2D]
    private let liveTimer = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()

    init(run: UIRun) {
        self.run = run
        let mockedRoute = [
            CLLocationCoordinate2D(latitude: 37.7768, longitude: -122.4236),
            CLLocationCoordinate2D(latitude: 37.7779, longitude: -122.4208),
            CLLocationCoordinate2D(latitude: 37.7795, longitude: -122.4182),
            CLLocationCoordinate2D(latitude: 37.7818, longitude: -122.4154),
            CLLocationCoordinate2D(latitude: 37.7845, longitude: -122.4129),
            CLLocationCoordinate2D(latitude: 37.7870, longitude: -122.4095)
        ]
        self.routeCoordinates = mockedRoute
        let initial = mockedRoute[1]
        _driverCoordinate = State(initialValue: initial)
        _mapPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7818, longitude: -122.4154),
                span: MKCoordinateSpan(latitudeDelta: 0.022, longitudeDelta: 0.022)
            )
        ))
    }

    private var activeRole: RunViewerRole {
        RunViewerRole(rawValue: activeRoleRawValue) ?? .driver
    }

    private var destinationCoordinate: CLLocationCoordinate2D {
        routeCoordinates.last ?? driverCoordinate
    }

    private var etaMinutes: Int {
        let remaining = max(0.0, 1.0 - liveProgress)
        return max(1, Int((remaining * 16.0).rounded()))
    }

    private var distanceRemainingText: String {
        let remaining = max(0.0, remainingDistanceMiles())
        return String(format: "%.1f mi remaining", remaining)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                mapCard
                statusCard
                participantsCard
                actionsCard
            }
            .padding(16)
        }
        .background(UIRunDesignSystem.background.ignoresSafeArea())
        .navigationTitle("Run Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(liveTimer) { _ in
            guard liveState != .completed else { return }
            stepLiveLocation()
        }
    }

    private var mapCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 12) {
                Text(run.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)

                Map(position: $mapPosition, interactionModes: .all) {
                    Annotation("Driver", coordinate: driverCoordinate) {
                        ZStack {
                            Circle()
                                .fill(UIRunDesignSystem.primary)
                                .frame(width: 16, height: 16)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 16, height: 16)
                        }
                    }

                    Marker("Destination", coordinate: destinationCoordinate)
                        .tint(.red)

                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(UIRunDesignSystem.primary.opacity(0.8), lineWidth: 5)
                }
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 14) {
                    Label("ETA \(etaMinutes) min", systemImage: "clock.fill")
                    Label(distanceRemainingText, systemImage: "location.fill")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.textSecondary)
            }
        }
    }

    private var statusCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Status")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)

                Text(liveState.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.primary)

                HStack(spacing: 0) {
                    ForEach(Array(OperationalRunState.allCases.enumerated()), id: \.offset) { idx, state in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(idx <= liveState.stepIndex ? UIRunDesignSystem.primary : Color.gray.opacity(0.25))
                                .frame(width: 14, height: 14)
                            Text(shortLabel(for: state))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(idx <= liveState.stepIndex ? UIRunDesignSystem.primary : UIRunDesignSystem.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        if idx < OperationalRunState.allCases.count - 1 {
                            Rectangle()
                                .fill(idx < liveState.stepIndex ? UIRunDesignSystem.primary.opacity(0.55) : Color.gray.opacity(0.22))
                                .frame(height: 2)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var participantsCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Participants")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)

                HStack(spacing: 10) {
                    avatar(initials: initials(for: run.driverName), size: 40, fill: UIRunDesignSystem.primary.opacity(0.18), textColor: UIRunDesignSystem.primary)
                    Text(run.driverName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                    Spacer()
                    Button("Contact") {
                        print("Contact driver placeholder")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .buttonStyle(.plain)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(run.passengers) { passenger in
                            avatarPill(name: passenger.name)
                        }
                    }
                }
            }
        }
    }

    private var actionsCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Actions")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)

                if activeRole == .driver {
                    UIPrimaryButton(title: "Mark Arrived", icon: "mappin.and.ellipse") {
                        liveState = .pickedUp
                        liveProgress = max(liveProgress, 0.45)
                    }
                    UISecondaryButton(title: "Start Drop-off", icon: "car.fill") {
                        liveState = .enRouteToDropOff
                        liveProgress = max(liveProgress, 0.68)
                    }
                    UISecondaryButton(title: "Complete Run", icon: "checkmark.circle.fill") {
                        liveState = .completed
                        liveProgress = 1.0
                        routeStepIndex = routeCoordinates.count - 1
                        driverCoordinate = destinationCoordinate
                    }
                } else {
                    UIPrimaryButton(title: "Track Live", icon: "location.viewfinder") {
                        centerOnDriver()
                    }
                    UISecondaryButton(title: "Contact Driver", icon: "phone.fill") {
                        print("Contact Driver placeholder")
                    }
                }
            }
        }
    }

    private func stepLiveLocation() {
        let nextIndex = min(routeStepIndex + 1, routeCoordinates.count - 1)
        routeStepIndex = nextIndex
        driverCoordinate = routeCoordinates[nextIndex]

        let computedProgress = Double(nextIndex) / Double(max(1, routeCoordinates.count - 1))
        liveProgress = computedProgress

        if computedProgress < 0.35 {
            liveState = .enRouteToPickup
        } else if computedProgress < 0.52 {
            liveState = .pickedUp
        } else if computedProgress < 1.0 {
            liveState = .enRouteToDropOff
        } else {
            liveState = .completed
        }
    }

    private func centerOnDriver() {
        mapPosition = .region(
            MKCoordinateRegion(
                center: driverCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
            )
        )
    }

    private func remainingDistanceMiles() -> Double {
        guard routeStepIndex < routeCoordinates.count - 1 else { return 0 }
        var meters: CLLocationDistance = 0
        for idx in routeStepIndex..<(routeCoordinates.count - 1) {
            let start = CLLocation(latitude: routeCoordinates[idx].latitude, longitude: routeCoordinates[idx].longitude)
            let end = CLLocation(latitude: routeCoordinates[idx + 1].latitude, longitude: routeCoordinates[idx + 1].longitude)
            meters += start.distance(from: end)
        }
        return meters / 1609.34
    }

    private func shortLabel(for state: OperationalRunState) -> String {
        switch state {
        case .enRouteToPickup: return "To Pickup"
        case .pickedUp: return "Picked Up"
        case .enRouteToDropOff: return "To Drop-off"
        case .completed: return "Done"
        }
    }

    private func initials(for name: String) -> String {
        name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private func avatar(initials: String, size: CGFloat, fill: Color, textColor: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(textColor)
            }
    }

    private func avatarPill(name: String) -> some View {
        HStack(spacing: 6) {
            avatar(initials: initials(for: name), size: 26, fill: UIRunDesignSystem.primary.opacity(0.14), textColor: UIRunDesignSystem.primary)
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.08))
        .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        RunDetailView(run: UIRunMockData.activeRun)
    }
}
