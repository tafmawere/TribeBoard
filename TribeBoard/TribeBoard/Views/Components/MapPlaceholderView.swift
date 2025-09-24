import SwiftUI

/// Static placeholder component for map display with location indicators
struct SchoolRunMapPlaceholder: View {
    let currentStop: RunStop?
    let showCurrentLocation: Bool
    let mapStyle: MapStyle
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    enum MapStyle {
        case overview
        case execution
        case thumbnail
    }
    
    init(currentStop: RunStop? = nil, showCurrentLocation: Bool = true, mapStyle: MapStyle = .overview) {
        self.currentStop = currentStop
        self.showCurrentLocation = showCurrentLocation
        self.mapStyle = mapStyle
    }
    
    var body: some View {
        ZStack {
            // Background map pattern
            backgroundMapPattern
            
            // Location indicators
            locationIndicators
            
            // Current location indicator (if enabled)
            if showCurrentLocation {
                currentLocationIndicator
            }
            
            // Route visualization (if in execution mode)
            if mapStyle == .execution {
                routeVisualization
            }
            
            // Map controls overlay (not for thumbnail)
            if mapStyle != .thumbnail {
                VStack {
                    HStack {
                        Spacer()
                        mapControlsOverlay
                    }
                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .lightShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("MapPlaceholder_\(mapStyle)")
        .onAppear {
            pulseScale = 1.2
        }
    }
    
    private var cornerRadius: CGFloat {
        switch mapStyle {
        case .thumbnail:
            return BrandStyle.cornerRadiusSmall
        default:
            return BrandStyle.cornerRadius
        }
    }
    
    // MARK: - Background Map Pattern
    
    private var backgroundMapPattern: some View {
        ZStack {
            // Base gradient background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(.systemGray6),
                            Color(.systemGray5)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Street grid pattern
            streetGridPattern
            
            // Neighborhood blocks
            neighborhoodBlocks
        }
    }
    
    private var streetGridPattern: some View {
        ZStack {
            // Horizontal streets
            VStack(spacing: mapStyle == .thumbnail ? 20 : 40) {
                ForEach(0..<(mapStyle == .thumbnail ? 2 : 4)) { _ in
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: mapStyle == .thumbnail ? 1 : 2)
                        .opacity(0.6)
                }
            }
            
            // Vertical streets
            HStack(spacing: mapStyle == .thumbnail ? 30 : 60) {
                ForEach(0..<(mapStyle == .thumbnail ? 2 : 3)) { _ in
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: mapStyle == .thumbnail ? 1 : 2)
                        .opacity(0.4)
                }
            }
        }
    }
    
    private var neighborhoodBlocks: some View {
        ZStack {
            // Scattered building blocks
            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray3))
                        .frame(width: mapStyle == .thumbnail ? 8 : 16, height: mapStyle == .thumbnail ? 6 : 12)
                        .opacity(0.3)
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray3))
                        .frame(width: mapStyle == .thumbnail ? 6 : 12, height: mapStyle == .thumbnail ? 8 : 16)
                        .opacity(0.3)
                }
                .padding(.horizontal, mapStyle == .thumbnail ? 8 : 20)
                
                Spacer()
                
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray3))
                        .frame(width: mapStyle == .thumbnail ? 10 : 20, height: mapStyle == .thumbnail ? 5 : 10)
                        .opacity(0.3)
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray3))
                        .frame(width: mapStyle == .thumbnail ? 7 : 14, height: mapStyle == .thumbnail ? 9 : 18)
                        .opacity(0.3)
                    Spacer()
                }
                
                Spacer()
                
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray3))
                        .frame(width: mapStyle == .thumbnail ? 9 : 18, height: mapStyle == .thumbnail ? 7 : 14)
                        .opacity(0.3)
                    Spacer()
                }
                .padding(.horizontal, mapStyle == .thumbnail ? 12 : 30)
            }
            .padding(mapStyle == .thumbnail ? 4 : 12)
        }
    }
    
    // MARK: - Location Indicators
    
    private var locationIndicators: some View {
        ZStack {
            if mapStyle == .thumbnail {
                // Single centered pin for thumbnail
                if let currentStop = currentStop {
                    locationPin(type: currentStop.type, isActive: true, size: .small)
                } else {
                    locationPin(type: .custom, isActive: false, size: .small)
                }
            } else {
                // Multiple pins for full map
                VStack {
                    HStack {
                        locationPin(type: .home, isActive: currentStop?.type == .home, size: .medium)
                        Spacer()
                        locationPin(type: .school, isActive: currentStop?.type == .school, size: .medium)
                    }
                    .padding(.horizontal, mapStyle == .execution ? 20 : 30)
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        locationPin(type: .music, isActive: currentStop?.type == .music, size: .medium)
                        Spacer()
                        locationPin(type: .ot, isActive: currentStop?.type == .ot, size: .medium)
                        Spacer()
                    }
                    
                    Spacer()
                    
                    HStack {
                        locationPin(type: .custom, isActive: currentStop?.type == .custom, size: .medium)
                        Spacer()
                    }
                    .padding(.horizontal, mapStyle == .execution ? 25 : 40)
                }
                .padding(mapStyle == .execution ? DesignSystem.Spacing.lg : DesignSystem.Spacing.xl)
            }
        }
    }
    
    // MARK: - Location Pin
    
    enum PinSize {
        case small, medium, large
        
        var circleSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 32
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }
    }
    
    private func locationPin(type: RunStop.StopType, isActive: Bool, size: PinSize = .medium) -> some View {
        VStack(spacing: size == .small ? 2 : 4) {
            ZStack {
                Circle()
                    .fill(isActive ? LinearGradient.brandGradient : LinearGradient(colors: [Color(.systemGray2), Color(.systemGray3)], startPoint: .top, endPoint: .bottom))
                    .frame(width: size.circleSize, height: size.circleSize)
                    .scaleEffect(isActive ? 1.2 : 1.0)
                    .animation(reduceMotion ? nil : .spring(response: 0.3), value: isActive)
                    .lightShadow()
                
                Image(systemName: type.sfSymbol)
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundColor(isActive ? .white : .secondary)
            }
            
            if isActive && size != .small {
                Text(type.rawValue)
                    .captionSmall()
                    .foregroundColor(.brandPrimary)
                    .fontWeight(.semibold)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                            .fill(Color(.systemBackground))
                            .lightShadow()
                    )
            }
        }
    }
    
    // MARK: - Route Visualization
    
    private var routeVisualization: some View {
        ZStack {
            // Route path (simplified curved line)
            Path { path in
                let width = UIScreen.main.bounds.width - 40
                let height: CGFloat = 200
                
                // Start point (bottom left)
                path.move(to: CGPoint(x: width * 0.2, y: height * 0.8))
                
                // Curve to middle point
                path.addQuadCurve(
                    to: CGPoint(x: width * 0.5, y: height * 0.3),
                    control: CGPoint(x: width * 0.3, y: height * 0.5)
                )
                
                // Curve to end point (top right)
                path.addQuadCurve(
                    to: CGPoint(x: width * 0.8, y: height * 0.2),
                    control: CGPoint(x: width * 0.7, y: height * 0.1)
                )
            }
            .stroke(
                LinearGradient.brandGradient,
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 4])
            )
            .opacity(0.8)
        }
    }
    
    // MARK: - Current Location Indicator
    
    private var currentLocationIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                ZStack {
                    // Pulsing circle
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: mapStyle == .thumbnail ? 20 : 40, height: mapStyle == .thumbnail ? 20 : 40)
                        .scaleEffect(pulseScale)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseScale)
                    
                    // Center dot
                    Circle()
                        .fill(Color.blue)
                        .frame(width: mapStyle == .thumbnail ? 6 : 12, height: mapStyle == .thumbnail ? 6 : 12)
                }
                
                Spacer()
            }
            .padding(.bottom, mapStyle == .thumbnail ? 8 : 60)
        }
    }
    
    @State private var pulseScale: CGFloat = 1.0
    
    // MARK: - Accessibility Properties
    
    private var accessibilityLabel: String {
        switch mapStyle {
        case .thumbnail:
            if let currentStop = currentStop {
                return "Map thumbnail for \(currentStop.name)"
            } else {
                return "Map thumbnail"
            }
        case .execution:
            if let currentStop = currentStop {
                return "Execution map showing current location at \(currentStop.name)"
            } else {
                return "Execution map view"
            }
        case .overview:
            return "Map overview showing all stop locations"
        }
    }
    
    private var accessibilityHint: String {
        switch mapStyle {
        case .thumbnail:
            return "Static map preview for this stop location"
        case .execution:
            return "Map view for navigation during run execution"
        case .overview:
            return "Overview of all stops on the route"
        }
    }
    
    private var accessibilityValue: String {
        var components: [String] = []
        
        if let currentStop = currentStop {
            components.append("Current stop: \(currentStop.name), \(currentStop.type.rawValue)")
        }
        
        if showCurrentLocation {
            components.append("Current location indicator visible")
        }
        
        return components.joined(separator: ", ")
    }
    
    // MARK: - Map Controls Overlay
    
    private var mapControlsOverlay: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Zoom controls
            VStack(spacing: 2) {
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemBackground))
                                .lightShadow()
                        )
                }
                .disabled(true) // Static placeholder - no functionality
                
                Button(action: {}) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemBackground))
                                .lightShadow()
                        )
                }
                .disabled(true) // Static placeholder - no functionality
            }
            
            // Current location button
            if showCurrentLocation {
                Button(action: {}) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.brandPrimary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemBackground))
                                .lightShadow()
                        )
                }
                .disabled(true) // Static placeholder - no functionality
            }
        }
    }
}

// MARK: - Thumbnail Variant

struct MapPlaceholderThumbnail: View {
    let stopType: RunStop.StopType?
    
    init(for stopType: RunStop.StopType? = nil) {
        self.stopType = stopType
    }
    
    var body: some View {
        SchoolRunMapPlaceholder(
            currentStop: stopType.map { type in
                RunStop(name: type.rawValue, type: type, task: "", estimatedMinutes: 5)
            },
            showCurrentLocation: false,
            mapStyle: .thumbnail
        )
        .frame(width: 60, height: 40)
    }
}

// MARK: - Preview

#Preview("Map Placeholder - All Styles") {
    ScrollView {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Overview style
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Overview Style")
                    .headlineSmall()
                
                SchoolRunMapPlaceholder(
                    currentStop: SchoolRunPreviewProvider.sampleStops[1],
                    showCurrentLocation: true,
                    mapStyle: .overview
                )
                .frame(height: 250)
            }
            
            // Execution style with route
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Execution Style")
                    .headlineSmall()
                
                SchoolRunMapPlaceholder(
                    currentStop: SchoolRunPreviewProvider.sampleStops[0],
                    showCurrentLocation: true,
                    mapStyle: .execution
                )
                .frame(height: 300)
            }
            
            // Thumbnail versions
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Thumbnail Variants")
                    .headlineSmall()
                
                HStack(spacing: DesignSystem.Spacing.md) {
                    MapPlaceholderThumbnail(for: .home)
                    MapPlaceholderThumbnail(for: .school)
                    MapPlaceholderThumbnail(for: .music)
                    MapPlaceholderThumbnail(for: .ot)
                    MapPlaceholderThumbnail(for: .custom)
                }
            }
        }
        .screenPadding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Map Placeholder - Dark Mode") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        SchoolRunMapPlaceholder(
            currentStop: SchoolRunPreviewProvider.sampleStops[1],
            showCurrentLocation: true,
            mapStyle: .overview
        )
        .frame(height: 250)
        
        HStack(spacing: DesignSystem.Spacing.md) {
            MapPlaceholderThumbnail(for: .home)
            MapPlaceholderThumbnail(for: .school)
            MapPlaceholderThumbnail(for: .music)
        }
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Map Placeholder - Execution States") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        // At home
        SchoolRunMapPlaceholder(
            currentStop: SchoolRunPreviewProvider.sampleStops[0],
            showCurrentLocation: true,
            mapStyle: .execution
        )
        .frame(height: 200)
        
        // At school
        SchoolRunMapPlaceholder(
            currentStop: SchoolRunPreviewProvider.sampleStops[1],
            showCurrentLocation: true,
            mapStyle: .execution
        )
        .frame(height: 200)
        
        // At music academy
        SchoolRunMapPlaceholder(
            currentStop: SchoolRunPreviewProvider.sampleStops[3],
            showCurrentLocation: true,
            mapStyle: .execution
        )
        .frame(height: 200)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Map Placeholder - Reduced Motion") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        SchoolRunMapPlaceholder(
            currentStop: SchoolRunPreviewProvider.sampleStops[1],
            showCurrentLocation: true,
            mapStyle: .execution
        )
        .frame(height: 250)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))

}

#Preview("Map Placeholder - Interactive") {
    SchoolRunMapPlaceholder(
        currentStop: SchoolRunPreviewProvider.sampleStops[1],
        showCurrentLocation: true,
        mapStyle: .overview
    )
    .frame(height: 300)
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .previewDisplayName("Interactive Map")
}