import SwiftUI
import MapKit
import CoreLocation
import Combine

struct LiveTrackingView: View {
    let run: UIRun

    @State private var mapPosition: MapCameraPosition
    @State private var driverCoordinate: CLLocationCoordinate2D
    @State private var routeStepIndex: Int = 1
    @State private var isSheetExpanded = false
    @State private var sheetDragOffset: CGFloat = 0

    private let routeCoordinates: [CLLocationCoordinate2D]
    private let liveTimer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()

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
                center: initial,
                span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
            )
        ))
    }

    private var destinationCoordinate: CLLocationCoordinate2D {
        routeCoordinates.last ?? driverCoordinate
    }

    private var etaMinutes: Int {
        let progress = Double(routeStepIndex) / Double(max(1, routeCoordinates.count - 1))
        let remaining = max(0.0, 1.0 - progress)
        return max(1, Int((remaining * 14.0).rounded()))
    }

    private var distanceRemainingText: String {
        String(format: "%.1f mi", remainingDistanceMiles())
    }

    private var statusText: String {
        let progress = Double(routeStepIndex) / Double(max(1, routeCoordinates.count - 1))
        if progress < 0.35 { return "En Route to Pickup" }
        if progress < 0.52 { return "Picked Up" }
        if progress < 1.0 { return "En Route to Drop-off" }
        return "Completed"
    }

    private var bottomSheetHeight: CGFloat {
        isSheetExpanded ? 360 : 122
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $mapPosition, interactionModes: .all) {
                Annotation("Driver", coordinate: driverCoordinate) {
                    ZStack {
                        Circle()
                            .fill(UIRunDesignSystem.primary)
                            .frame(width: 18, height: 18)
                        Circle()
                            .stroke(Color.white, lineWidth: 2.2)
                            .frame(width: 18, height: 18)
                    }
                }

                Marker("Destination", coordinate: destinationCoordinate)
                    .tint(.red)

                MapPolyline(coordinates: routeCoordinates)
                    .stroke(UIRunDesignSystem.primary.opacity(0.85), lineWidth: 5)
            }
            .ignoresSafeArea()

            floatingActionButtons
                .padding(.trailing, 16)
                .padding(.bottom, 150)
                .frame(maxWidth: .infinity, alignment: .trailing)

            bottomSheet
                .offset(y: max(0, sheetDragOffset))
                .gesture(sheetDragGesture)
                .animation(.spring(response: 0.32, dampingFraction: 0.84), value: isSheetExpanded)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.86), value: sheetDragOffset)
        }
        .navigationTitle("Live Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(liveTimer) { _ in
            stepLiveLocation()
        }
    }

    private var floatingActionButtons: some View {
        VStack(spacing: 10) {
            fabButton(icon: "phone.fill", tint: UIRunDesignSystem.primary) {
                print("Call driver placeholder")
            }
            fabButton(icon: "cross.case.fill", tint: RunStitchTheme.danger) {
                print("Emergency placeholder")
            }
            fabButton(icon: "square.and.arrow.up.fill", tint: UIRunDesignSystem.secondary) {
                print("Share run placeholder")
            }
        }
    }

    private var bottomSheet: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 38, height: 5)
                .padding(.top, 8)
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        isSheetExpanded.toggle()
                    }
                }

            collapsedHeader

            if isSheetExpanded {
                Divider().padding(.horizontal, 2)
                expandedContent
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: bottomSheetHeight, alignment: .top)
        .padding(.horizontal, 12)
        .background(
            LinearGradient(
                colors: [Color.white, UIRunDesignSystem.background.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: -2)
    }

    private var collapsedHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(UIRunDesignSystem.primary.opacity(0.16))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(initials(for: run.driverName))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.primary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Text("Driver: \(run.driverName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("ETA \(etaMinutes) min")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.primary)
                Text("\(distanceRemainingText) remaining")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            }
        }
        .padding(.horizontal, 8)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Passengers")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(run.passengers) { passenger in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(UIRunDesignSystem.primary.opacity(0.14))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Text(initials(for: passenger.name))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(UIRunDesignSystem.primary)
                                }
                            Text(passenger.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.10))
                        .clipShape(Capsule())
                    }
                }
            }

            Text("Timeline")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)
                .padding(.top, 2)

            VStack(spacing: 8) {
                ForEach(UIRunMockData.timeline.prefix(3)) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(UIRunDesignSystem.primary.opacity(0.20))
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                                Spacer()
                                Text(item.timeText)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                            }
                            Text(item.subtitle)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                        }
                    }
                }
            }

            UIPrimaryButton(title: "Contact Driver", icon: "phone.fill") {
                print("Contact driver placeholder")
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 8)
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                sheetDragOffset = value.translation.height
            }
            .onEnded { value in
                defer { sheetDragOffset = 0 }
                let shouldExpand = value.translation.height < -35
                let shouldCollapse = value.translation.height > 35
                if shouldExpand {
                    isSheetExpanded = true
                } else if shouldCollapse {
                    isSheetExpanded = false
                }
            }
    }

    private func stepLiveLocation() {
        let nextIndex = min(routeStepIndex + 1, routeCoordinates.count - 1)
        guard nextIndex != routeStepIndex else { return }
        routeStepIndex = nextIndex

        withAnimation(.easeInOut(duration: 0.9)) {
            driverCoordinate = routeCoordinates[nextIndex]
            mapPosition = .region(
                MKCoordinateRegion(
                    center: driverCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.016, longitudeDelta: 0.016)
                )
            )
        }
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

    private func initials(for name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private func fabButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(tint)
                .clipShape(Circle())
                .shadow(color: tint.opacity(0.34), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        LiveTrackingView(run: UIRunMockData.activeRun)
    }
}
