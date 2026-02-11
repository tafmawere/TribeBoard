//
//  FeaturedEventCard.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Large, prominent card displaying the next upcoming event with rich visual information
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 12.1**
struct FeaturedEventCard: View {
    let run: Run
    let onViewDetails: () -> Void
    let onShare: () -> Void
    
    private var eventType: String {
        // Extract event type from run title or use default
        if run.title.lowercased().contains("soccer") {
            return "Soccer"
        } else if run.title.lowercased().contains("school") {
            return "School"
        } else if run.title.lowercased().contains("practice") {
            return "Practice"
        } else {
            return "Activity"
        }
    }
    
    private var heroImageName: String {
        // Return placeholder image name based on event type
        switch eventType.lowercased() {
        case "soccer":
            return "soccer_hero"
        case "school":
            return "school_hero"
        case "practice":
            return "practice_hero"
        default:
            return "activity_hero"
        }
    }
    
    private var driverName: String? {
        // Find driver from passengers
        run.passengers.first(where: { $0.role == .driver })?.displayName
    }
    
    private var location: String {
        // Get location from first stop or use default
        run.stops.first?.location.address ?? "Location TBD"
    }
    
    private var participants: [User] {
        // Convert MemberSummary to User for ParticipantAvatarsView
        run.passengers.map { member in
            User(
                id: member.id,
                displayName: member.displayName,
                role: convertMemberRoleToFamilyRole(member.role),
                familyId: run.familyId,
                avatarURL: member.avatarURL
            )
        }
    }
    
    private func convertMemberRoleToFamilyRole(_ memberRole: MemberRole) -> FamilyRole {
        switch memberRole {
        case .driver:
            return .driver
        case .observer:
            return .observer
        case .passenger:
            return .observer // Map passenger to observer for display purposes
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero Image with Event Type Badge
            ZStack(alignment: .topTrailing) {
                HeroImageView(imageName: heroImageName)
                
                EventTypeBadge(eventType: eventType)
                    .padding(8)
            }
            
            // Event Details
            VStack(alignment: .leading, spacing: 12) {
                // "UPCOMING EVENT" Label
                Text("UPCOMING EVENT")
                    .font(DesignSystem.Typography.captionBold)
                    .foregroundColor(DesignSystem.Colors.primaryBrand)
                
                // Event Title
                Text(run.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                // Time with Clock Icon
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text(formatTime(run.scheduledTime))
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Time: \(formatTime(run.scheduledTime))")
                
                // Location with Pin Icon
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text(location)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Location: \(location)")
                
                // Driver Information
                if let driverName = driverName {
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("Driver: \(driverName)")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Driver: \(driverName)")
                }
                
                // Participant Avatars
                if !participants.isEmpty {
                    HStack(spacing: 8) {
                        Text("Participants:")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        ParticipantAvatarsView(participants: participants)
                    }
                    .padding(.top, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(participants.count) \(participants.count == 1 ? "participant" : "participants")")
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    // View Details Button
                    Button(action: onViewDetails) {
                        Text("View Details")
                            .font(DesignSystem.Typography.heading)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .frame(minHeight: 48) // Ensure minimum touch target
                            .background(DesignSystem.Colors.primaryBrand)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                    .accessibilityLabel("View Details")
                    .accessibilityHint("Opens detailed information about \(run.title)")
                    
                    // Share Button
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundColor(DesignSystem.Colors.primaryBrand)
                            .frame(width: 48, height: 48)
                            .background(DesignSystem.Colors.primaryBlueLight)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                    .accessibilityLabel("Share")
                    .accessibilityHint("Share this run with others")
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(
            color: DesignSystem.Shadow.card.color,
            radius: DesignSystem.Shadow.card.radius,
            x: DesignSystem.Shadow.card.x,
            y: DesignSystem.Shadow.card.y
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Hero Image View

private struct HeroImageView: View {
    let imageName: String
    
    var body: some View {
        ZStack {
            // Try to load the image, fall back to gradient if not available
            if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
            } else {
                // Placeholder gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        DesignSystem.Colors.primaryBrand.opacity(0.6),
                        DesignSystem.Colors.primaryBrand.opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 200)
                .overlay(
                    Image(systemName: placeholderIcon(for: imageName))
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))
                )
            }
        }
        .frame(height: 200)
    }
    
    private func placeholderIcon(for imageName: String) -> String {
        if imageName.contains("soccer") {
            return "sportscourt.fill"
        } else if imageName.contains("school") {
            return "building.2.fill"
        } else if imageName.contains("practice") {
            return "figure.run"
        } else {
            return "calendar"
        }
    }
}

// MARK: - Event Type Badge

private struct EventTypeBadge: View {
    let eventType: String
    
    var body: some View {
        Text(eventType.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.6))
            )
    }
}

// MARK: - Previews

#Preview("Featured Event Card - Soccer") {
    FeaturedEventCard(
        run: Run(
            title: "Soccer Practice",
            scheduledTime: Date().addingTimeInterval(3600),
            driverId: "driver1",
            stops: [
                RunStop(
                    type: .pickup,
                    label: "Home",
                    scheduledTime: Date().addingTimeInterval(3600),
                    requiredPassengerIds: ["1", "2"],
                    location: LocationData(
                        latitude: 37.7749,
                        longitude: -122.4194,
                        address: "123 Main St, San Francisco, CA"
                    )
                )
            ],
            passengers: [
                MemberSummary(id: "driver1", displayName: "John Doe", role: .driver),
                MemberSummary(id: "1", displayName: "Alice Smith", role: .passenger),
                MemberSummary(id: "2", displayName: "Bob Johnson", role: .passenger)
            ],
            createdBy: "user1",
            familyId: "family1"
        ),
        onViewDetails: {},
        onShare: {}
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Featured Event Card - School") {
    FeaturedEventCard(
        run: Run(
            title: "School Drop-off",
            scheduledTime: Date().addingTimeInterval(7200),
            driverId: "driver2",
            stops: [
                RunStop(
                    type: .dropoff,
                    label: "Lincoln Elementary",
                    scheduledTime: Date().addingTimeInterval(7200),
                    requiredPassengerIds: ["3", "4"],
                    location: LocationData(
                        latitude: 37.7849,
                        longitude: -122.4094,
                        address: "456 School Ave, San Francisco, CA"
                    )
                )
            ],
            passengers: [
                MemberSummary(id: "driver2", displayName: "Jane Wilson", role: .driver),
                MemberSummary(id: "3", displayName: "Charlie Brown", role: .passenger),
                MemberSummary(id: "4", displayName: "Diana Prince", role: .passenger),
                MemberSummary(id: "5", displayName: "Eve Adams", role: .passenger),
                MemberSummary(id: "6", displayName: "Frank Miller", role: .passenger),
                MemberSummary(id: "7", displayName: "Grace Lee", role: .passenger)
            ],
            createdBy: "user2",
            familyId: "family1"
        ),
        onViewDetails: {},
        onShare: {}
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Featured Event Card - No Driver") {
    FeaturedEventCard(
        run: Run(
            title: "Basketball Practice",
            scheduledTime: Date().addingTimeInterval(5400),
            driverId: "",
            stops: [
                RunStop(
                    type: .pickup,
                    label: "Community Center",
                    scheduledTime: Date().addingTimeInterval(5400),
                    requiredPassengerIds: ["8"],
                    location: LocationData(
                        latitude: 37.7649,
                        longitude: -122.4294,
                        address: "789 Center Blvd, San Francisco, CA"
                    )
                )
            ],
            passengers: [
                MemberSummary(id: "8", displayName: "Henry Ford", role: .passenger)
            ],
            createdBy: "user3",
            familyId: "family1"
        ),
        onViewDetails: {},
        onShare: {}
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Dark Mode") {
    FeaturedEventCard(
        run: Run(
            title: "Soccer Practice",
            scheduledTime: Date().addingTimeInterval(3600),
            driverId: "driver1",
            stops: [
                RunStop(
                    type: .pickup,
                    label: "Home",
                    scheduledTime: Date().addingTimeInterval(3600),
                    requiredPassengerIds: ["1", "2"],
                    location: LocationData(
                        latitude: 37.7749,
                        longitude: -122.4194,
                        address: "123 Main St, San Francisco, CA"
                    )
                )
            ],
            passengers: [
                MemberSummary(id: "driver1", displayName: "John Doe", role: .driver),
                MemberSummary(id: "1", displayName: "Alice Smith", role: .passenger),
                MemberSummary(id: "2", displayName: "Bob Johnson", role: .passenger)
            ],
            createdBy: "user1",
            familyId: "family1"
        ),
        onViewDetails: {},
        onShare: {}
    )
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
