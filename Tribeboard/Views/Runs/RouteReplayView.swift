import SwiftUI
import MapKit
import CoreLocation
import Combine

struct ReplayRoutePoint: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date

    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D, timestamp: Date) {
        self.id = id
        self.coordinate = coordinate
        self.timestamp = timestamp
    }
}

struct ReplayEventMarker: Identifiable {
    let id: UUID
    let title: String
    let symbol: String
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date

    init(id: UUID = UUID(), title: String, symbol: String, coordinate: CLLocationCoordinate2D, timestamp: Date) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.coordinate = coordinate
        self.timestamp = timestamp
    }
}

struct RouteReplayView: View {
    let run: UIRun
    let routePoints: [ReplayRoutePoint]
    let eventMarkers: [ReplayEventMarker]

    @State private var mapPosition: MapCameraPosition
    @State private var driverCoordinate: CLLocationCoordinate2D
    @State private var replayDate: Date
    @State private var isPlaying = true
    @State private var playbackSpeed: Double = 1.0
    @State private var lastTickDate = Date()
    @State private var firedEvents: Set<UUID> = []
    @State private var eventBannerText: String?

    private let frameTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    init(run: UIRun, routePoints: [ReplayRoutePoint], eventMarkers: [ReplayEventMarker]) {
        self.run = run
        self.routePoints = routePoints
        self.eventMarkers = eventMarkers

        let fallback = CLLocationCoordinate2D(latitude: 37.7818, longitude: -122.4154)
        let initialCoordinate = routePoints.first?.coordinate ?? fallback
        let initialTime = routePoints.first?.timestamp ?? Date()

        _driverCoordinate = State(initialValue: initialCoordinate)
        _replayDate = State(initialValue: initialTime)
        _mapPosition = State(initialValue: .region(Self.fittedRegion(for: routePoints.map(\.coordinate), fallback: fallback)))
    }

    private var startDate: Date {
        routePoints.first?.timestamp ?? replayDate
    }

    private var endDate: Date {
        routePoints.last?.timestamp ?? replayDate
    }

    private var sliderProgress: Double {
        let total = endDate.timeIntervalSince(startDate)
        guard total > 0 else { return 0 }
        return max(0, min(1, replayDate.timeIntervalSince(startDate) / total))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $mapPosition, interactionModes: .all) {
                MapPolyline(coordinates: routePoints.map(\.coordinate))
                    .stroke(UIRunDesignSystem.primary.opacity(0.85), lineWidth: 5)

                if let start = routePoints.first {
                    Annotation("Start", coordinate: start.coordinate) {
                        markerIcon(symbol: "play.fill", tint: UIRunDesignSystem.success)
                    }
                }

                if let end = routePoints.last {
                    Annotation("End", coordinate: end.coordinate) {
                        markerIcon(symbol: "flag.checkered", tint: .red)
                    }
                }

                ForEach(eventMarkers) { event in
                    Annotation(event.title, coordinate: event.coordinate) {
                        markerIcon(symbol: event.symbol, tint: UIRunDesignSystem.warning)
                    }
                }

                Annotation("Driver", coordinate: driverCoordinate) {
                    ZStack {
                        Circle()
                            .fill(UIRunDesignSystem.primary)
                            .frame(width: 18, height: 18)
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 18, height: 18)
                    }
                }
            }
            .ignoresSafeArea()

            if let eventBannerText {
                Text(eventBannerText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 190)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            controlsOverlay
        }
        .navigationTitle("Route Replay")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(frameTimer) { tick in
            guard isPlaying else {
                lastTickDate = tick
                return
            }
            let dt = tick.timeIntervalSince(lastTickDate)
            lastTickDate = tick
            advanceReplay(by: dt * playbackSpeed)
        }
        .onAppear {
            lastTickDate = Date()
        }
    }

    private var controlsOverlay: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    isPlaying.toggle()
                    lastTickDate = Date()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(UIRunDesignSystem.primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                ForEach([1.0, 2.0, 4.0], id: \.self) { speed in
                    Button {
                        playbackSpeed = speed
                    } label: {
                        Text("\(Int(speed))x")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(playbackSpeed == speed ? .white : UIRunDesignSystem.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(playbackSpeed == speed ? UIRunDesignSystem.primary : Color.white.opacity(0.88))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text(timestampText(replayDate))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            }

            Slider(
                value: Binding(
                    get: { sliderProgress },
                    set: { newValue in
                        let clamped = max(0, min(1, newValue))
                        let total = endDate.timeIntervalSince(startDate)
                        replayDate = startDate.addingTimeInterval(total * clamped)
                        updateDriverCoordinate(for: replayDate)
                        firedEvents = Set(eventMarkers.filter { $0.timestamp <= replayDate }.map(\.id))
                    }
                ),
                in: 0...1
            )
            .tint(UIRunDesignSystem.primary)
        }
        .padding(14)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 12)
        .padding(.bottom, 18)
    }

    private func advanceReplay(by delta: TimeInterval) {
        let nextReplayDate = replayDate.addingTimeInterval(delta)
        if nextReplayDate >= endDate {
            replayDate = endDate
            updateDriverCoordinate(for: replayDate)
            isPlaying = false
            return
        }

        let previous = replayDate
        replayDate = nextReplayDate
        updateDriverCoordinate(for: replayDate)
        triggerEventsIfNeeded(from: previous, to: replayDate)
    }

    private func updateDriverCoordinate(for timestamp: Date) {
        guard routePoints.count > 1 else {
            driverCoordinate = routePoints.first?.coordinate ?? driverCoordinate
            return
        }

        if timestamp <= routePoints[0].timestamp {
            driverCoordinate = routePoints[0].coordinate
            return
        }
        if timestamp >= routePoints[routePoints.count - 1].timestamp {
            driverCoordinate = routePoints[routePoints.count - 1].coordinate
            return
        }

        for index in 0..<(routePoints.count - 1) {
            let start = routePoints[index]
            let end = routePoints[index + 1]
            guard timestamp >= start.timestamp, timestamp <= end.timestamp else { continue }

            let segmentDuration = end.timestamp.timeIntervalSince(start.timestamp)
            let elapsed = timestamp.timeIntervalSince(start.timestamp)
            let progress = segmentDuration > 0 ? max(0, min(1, elapsed / segmentDuration)) : 0

            let lat = start.coordinate.latitude + (end.coordinate.latitude - start.coordinate.latitude) * progress
            let lon = start.coordinate.longitude + (end.coordinate.longitude - start.coordinate.longitude) * progress

            withAnimation(.linear(duration: 0.08)) {
                driverCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            return
        }
    }

    private func triggerEventsIfNeeded(from previous: Date, to current: Date) {
        guard current >= previous else { return }
        for event in eventMarkers where event.timestamp > previous && event.timestamp <= current {
            guard !firedEvents.contains(event.id) else { continue }
            firedEvents.insert(event.id)
            withAnimation(.easeInOut(duration: 0.2)) {
                eventBannerText = event.title
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    if eventBannerText == event.title {
                        eventBannerText = nil
                    }
                }
            }
        }
    }

    private func markerIcon(symbol: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint)
                .frame(width: 24, height: 24)
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func timestampText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }

    private static func fittedRegion(for coordinates: [CLLocationCoordinate2D], fallback: CLLocationCoordinate2D) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: fallback,
                span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
            )
        }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLon = lons.min(),
              let maxLon = lons.max()
        else {
            return MKCoordinateRegion(
                center: fallback,
                span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
            )
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let latDelta = max(0.012, (maxLat - minLat) * 1.55)
        let lonDelta = max(0.012, (maxLon - minLon) * 1.55)
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }
}

#Preview {
    let now = Date()
    let points: [ReplayRoutePoint] = [
        .init(coordinate: CLLocationCoordinate2D(latitude: 37.7768, longitude: -122.4236), timestamp: now),
        .init(coordinate: CLLocationCoordinate2D(latitude: 37.7779, longitude: -122.4208), timestamp: now.addingTimeInterval(70)),
        .init(coordinate: CLLocationCoordinate2D(latitude: 37.7795, longitude: -122.4182), timestamp: now.addingTimeInterval(180)),
        .init(coordinate: CLLocationCoordinate2D(latitude: 37.7818, longitude: -122.4154), timestamp: now.addingTimeInterval(255)),
        .init(coordinate: CLLocationCoordinate2D(latitude: 37.7845, longitude: -122.4129), timestamp: now.addingTimeInterval(420))
    ]

    let events: [ReplayEventMarker] = [
        .init(title: "Pickup", symbol: "figure.and.child.holdinghands", coordinate: points[2].coordinate, timestamp: points[2].timestamp),
        .init(title: "Drop-off", symbol: "flag.checkered", coordinate: points[4].coordinate, timestamp: points[4].timestamp)
    ]

    return NavigationStack {
        RouteReplayView(run: UIRunMockData.activeRun, routePoints: points, eventMarkers: events)
    }
}
