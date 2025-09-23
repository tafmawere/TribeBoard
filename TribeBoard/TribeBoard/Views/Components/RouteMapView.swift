import SwiftUI
import Foundation

/// Mock navigation interface showing GPS tracking and route progress
struct RouteMapView: View {
    let schoolRun: SchoolRun
    let trackingData: RouteTrackingData
    let onStopTracking: () -> Void
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Map mockup section
            mapMockupSection
            
            // Navigation info section
            navigationInfoSection
            
            // Progress and controls section
            progressSection
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Map Mockup Section
    
    private var mapMockupSection: some View {
        ZStack {
            // Background map mockup
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.green.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
            
            // Mock map elements
            mapElements
            
            // Navigation overlay
            navigationOverlay
        }
    }
    
    private var mapElements: some View {
        ZStack {
            // Mock roads
            mockRoads
            
            // Current location indicator
            currentLocationIndicator
            
            // Destination marker
            destinationMarker
            
            // Route line
            routeLine
        }
    }
    
    private var mockRoads: some View {
        VStack(spacing: 20) {
            // Horizontal roads
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 2)
                .offset(y: -30)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 2)
                .offset(y: 30)
            
            // Vertical road
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 2, height: 120)
        }
    }
    
    private var currentLocationIndicator: some View {
        VStack(spacing: 4) {
            // Pulsing circle for current location
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 30, height: 30)
                    .scaleEffect(pulseScale)
                    .animation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
            }
            
            Text("You")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
        .offset(x: progressOffset, y: 20)
    }
    
    private var destinationMarker: some View {
        VStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundColor(.red)
            
            Text("School")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.red)
        }
        .offset(x: 60, y: -40)
    }
    
    private var routeLine: some View {
        Path { path in
            let startX: CGFloat = progressOffset
            let startY: CGFloat = 120
            let endX: CGFloat = 60
            let endY: CGFloat = 60
            
            path.move(to: CGPoint(x: startX, y: startY))
            path.addQuadCurve(
                to: CGPoint(x: endX, y: endY),
                control: CGPoint(x: (startX + endX) / 2, y: startY - 30)
            )
        }
        .stroke(
            Color.blue,
            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 3])
        )
    }
    
    private var navigationOverlay: some View {
        VStack {
            HStack {
                Spacer()
                
                // Mock GPS signal indicator
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(0..<4) { index in
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: 3, height: CGFloat(4 + index * 2))
                                .opacity(index < 3 ? 1.0 : 0.5)
                        }
                    }
                    Text("GPS")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .padding(8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(6)
            }
            
            Spacer()
        }
        .padding(12)
    }
    
    // MARK: - Navigation Info Section
    
    private var navigationInfoSection: some View {
        VStack(spacing: 12) {
            // Current instruction
            navigationInstruction
            
            Divider()
            
            // Route details
            routeDetails
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var navigationInstruction: some View {
        HStack(spacing: 12) {
            // Direction icon
            Image(systemName: currentDirectionIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            // Instruction text
            VStack(alignment: .leading, spacing: 2) {
                Text(currentInstruction)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("in \(nextTurnDistance)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var routeDetails: some View {
        HStack(spacing: 20) {
            // Distance remaining
            VStack(alignment: .leading, spacing: 2) {
                Text("Distance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f mi", trackingData.distanceRemaining))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            // ETA
            VStack(alignment: .leading, spacing: 2) {
                Text("ETA")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(timeFormatter.string(from: trackingData.estimatedArrival))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // Current location
            VStack(alignment: .trailing, spacing: 2) {
                Text("Location")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(trackingData.currentLocation.address)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            // Progress bar
            progressBar
            
            // Control buttons
            controlButtons
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Route Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(trackingData.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * trackingData.progress, height: 6)
                        .cornerRadius(3)
                        .animation(.easeInOut(duration: 0.5), value: trackingData.progress)
                }
            }
            .frame(height: 6)
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 12) {
            // Stop tracking button
            Button(action: onStopTracking) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                    Text("Stop Navigation")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red)
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Mock arrival notification button
            Button("Notify Arrival") {
                // Mock action - would send arrival notification
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Computed Properties
    
    private var pulseScale: CGFloat {
        trackingData.isNavigating ? 1.2 : 1.0
    }
    
    private var progressOffset: CGFloat {
        let maxOffset: CGFloat = 60
        return -maxOffset + (maxOffset * 2 * CGFloat(trackingData.progress))
    }
    
    private var currentDirectionIcon: String {
        let progress = trackingData.progress
        
        if progress < 0.3 {
            return "arrow.up"
        } else if progress < 0.7 {
            return "arrow.turn.up.right"
        } else {
            return "arrow.right"
        }
    }
    
    private var currentInstruction: String {
        let progress = trackingData.progress
        
        if progress < 0.3 {
            return "Continue straight"
        } else if progress < 0.7 {
            return "Turn right on Main St"
        } else if progress < 0.9 {
            return "Destination ahead"
        } else {
            return "Arriving at destination"
        }
    }
    
    private var nextTurnDistance: String {
        let progress = trackingData.progress
        let remainingDistance = trackingData.distanceRemaining
        
        if progress < 0.3 {
            return "0.8 mi"
        } else if progress < 0.7 {
            return "0.3 mi"
        } else if progress < 0.9 {
            return "500 ft"
        } else {
            return "100 ft"
        }
    }
}

// MARK: - Preview

#Preview {
    let mockTrackingData = RouteTrackingData(
        currentLocation: MockLocation(
            latitude: 34.0522,
            longitude: -118.2437,
            address: "En route"
        ),
        destination: MockLocation(
            latitude: 34.0622,
            longitude: -118.2337,
            address: "Greenwood Elementary"
        ),
        estimatedArrival: Calendar.current.date(byAdding: .minute, value: 15, to: Date())!,
        distanceRemaining: 1.2,
        progress: 0.6,
        isNavigating: true
    )
    
    let mockSchoolRun = SchoolRun(
        id: UUID(),
        route: "Home → Greenwood Elementary",
        pickupTime: Date(),
        dropoffTime: Calendar.current.date(byAdding: .minute, value: 45, to: Date())!,
        driver: UUID(),
        passengers: [UUID()],
        status: .inProgress,
        notes: nil
    )
    
    return RouteMapView(
        schoolRun: mockSchoolRun,
        trackingData: mockTrackingData,
        onStopTracking: {}
    )
    .padding()
}