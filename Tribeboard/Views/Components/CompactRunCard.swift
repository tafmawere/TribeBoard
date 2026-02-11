//
//  CompactRunCard.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Compact card for displaying runs in the "Today's Runs" list
/// Displays status icon, run details, and status badge in a compact 80pt height layout
/// **Validates: Requirements 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 4.11**
struct CompactRunCard: View {
    let run: Run
    let onTap: () -> Void
    
    private var statusIcon: String {
        switch run.status {
        case .completed:
            return "checkmark.circle.fill"
        case .activeEnroute, .arrivedAtStop, .paused:
            return "car.fill"
        default:
            return "clock.fill"
        }
    }
    
    private var statusIconColor: Color {
        switch run.status {
        case .completed:
            return DesignSystem.Colors.successGreen
        case .activeEnroute, .arrivedAtStop, .paused:
            return DesignSystem.Colors.primaryBrand
        default:
            return DesignSystem.Colors.textSecondary
        }
    }
    
    private var statusBadgeText: String {
        if run.isDelayed {
            return "Delayed"
        }
        return run.status.displayName
    }
    
    private var statusBadgeStyle: StatusBadgeView.BadgeStyle {
        if run.isDelayed {
            return .warning
        }
        
        switch run.status {
        case .completed:
            return .success
        case .activeEnroute, .arrivedAtStop, .paused:
            return .primary
        default:
            return .secondary
        }
    }
    
    private var participantCount: Int {
        run.passengers.count
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status Icon
                Image(systemName: statusIcon)
                    .font(.system(size: 24))
                    .foregroundColor(statusIconColor)
                    .frame(width: 24, height: 24)
                
                // Run Info
                VStack(alignment: .leading, spacing: 4) {
                    // Run Title
                    Text(run.title)
                        .font(DesignSystem.Typography.heading)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    
                    // Time and Participant Count
                    HStack(spacing: 8) {
                        Text(formatTime(run.scheduledTime))
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("•")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("\(participantCount) participant\(participantCount == 1 ? "" : "s")")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Status Badge
                StatusBadgeView(text: statusBadgeText, style: statusBadgeStyle)
            }
            .padding(16)
            .frame(height: 80)
            .frame(minHeight: 80) // Ensure minimum touch target
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.radiusMedium)
            .shadow(
                color: DesignSystem.Shadow.card.color,
                radius: DesignSystem.Shadow.card.radius,
                x: DesignSystem.Shadow.card.x,
                y: DesignSystem.Shadow.card.y
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(run.title), \(formatTime(run.scheduledTime)), \(participantCount) \(participantCount == 1 ? "participant" : "participants"), \(statusBadgeText)")
        .accessibilityHint("View run details")
        .accessibilityAddTraits(.isButton)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Previews

#Preview("Scheduled Run") {
    CompactRunCard(
        run: Run(
            title: "Soccer Practice",
            scheduledTime: Date().addingTimeInterval(3600),
            driverId: "driver1",
            status: .scheduled,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "Home",
                    scheduledTime: Date().addingTimeInterval(3600),
                    requiredPassengerIds: ["1", "2"],
                    location: LocationData(
                        latitude: 37.7749,
                        longitude: -122.4194,
                        address: "123 Main St"
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
        onTap: {}
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Active Run") {
    CompactRunCard(
        run: Run(
            title: "School Drop-off",
            scheduledTime: Date(),
            driverId: "driver2",
            status: .activeEnroute,
            stops: [
                RunStop(
                    type: .dropoff,
                    label: "Lincoln Elementary",
                    scheduledTime: Date(),
                    requiredPassengerIds: ["3"],
                    location: LocationData(
                        latitude: 37.7849,
                        longitude: -122.4094,
                        address: "456 School Ave"
                    )
                )
            ],
            passengers: [
                MemberSummary(id: "driver2", displayName: "Jane Wilson", role: .driver),
                MemberSummary(id: "3", displayName: "Charlie Brown", role: .passenger)
            ],
            createdBy: "user2",
            familyId: "family1"
        ),
        onTap: {}
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Completed Run") {
    CompactRunCard(
        run: Run(
            title: "Basketball Practice",
            scheduledTime: Date().addingTimeInterval(-7200),
            driverId: "driver3",
            status: .completed,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "Community Center",
                    scheduledTime: Date().addingTimeInterval(-7200),
                    requiredPassengerIds: ["4", "5"],
                    location: LocationData(
                        latitude: 37.7649,
                        longitude: -122.4294,
                        address: "789 Center Blvd"
                    )
                )
            ],
            passengers: [
                MemberSummary(id: "driver3", displayName: "Mike Davis", role: .driver),
                MemberSummary(id: "4", displayName: "Diana Prince", role: .passenger),
                MemberSummary(id: "5", displayName: "Eve Adams", role: .passenger)
            ],
            createdBy: "user3",
            familyId: "family1"
        ),
        onTap: {}
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Delayed Run") {
    CompactRunCard(
        run: Run(
            title: "Piano Lesson",
            scheduledTime: Date().addingTimeInterval(1800),
            driverId: "driver4",
            status: .scheduled,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "Music School",
                    scheduledTime: Date().addingTimeInterval(1800),
                    requiredPassengerIds: ["6"],
                    location: LocationData(
                        latitude: 37.7549,
                        longitude: -122.4394,
                        address: "321 Music Lane"
                    )
                )
            ],
            passengers: [
                MemberSummary(id: "driver4", displayName: "Sarah Lee", role: .driver),
                MemberSummary(id: "6", displayName: "Frank Miller", role: .passenger)
            ],
            createdBy: "user4",
            familyId: "family1",
            isDelayed: true,
            delayReason: "Traffic"
        ),
        onTap: {}
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Single Participant") {
    CompactRunCard(
        run: Run(
            title: "Dentist Appointment",
            scheduledTime: Date().addingTimeInterval(5400),
            driverId: "driver5",
            status: .scheduled,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "Dental Office",
                    scheduledTime: Date().addingTimeInterval(5400),
                    requiredPassengerIds: ["7"],
                    location: LocationData(
                        latitude: 37.7449,
                        longitude: -122.4494,
                        address: "555 Health St"
                    )
                )
            ],
            passengers: [
                MemberSummary(id: "driver5", displayName: "Tom Harris", role: .driver)
            ],
            createdBy: "user5",
            familyId: "family1"
        ),
        onTap: {}
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("All Run States") {
    VStack(spacing: 12) {
        CompactRunCard(
            run: Run(
                title: "Scheduled Run",
                scheduledTime: Date().addingTimeInterval(3600),
                driverId: "driver1",
                status: .scheduled,
                stops: [
                    RunStop(
                        type: .pickup,
                        label: "Home",
                        scheduledTime: Date().addingTimeInterval(3600),
                        requiredPassengerIds: ["1"],
                        location: LocationData(latitude: 37.7749, longitude: -122.4194)
                    )
                ],
                passengers: [
                    MemberSummary(id: "driver1", displayName: "Driver", role: .driver),
                    MemberSummary(id: "1", displayName: "Passenger", role: .passenger)
                ],
                createdBy: "user1",
                familyId: "family1"
            ),
            onTap: {}
        )
        
        CompactRunCard(
            run: Run(
                title: "Active Run",
                scheduledTime: Date(),
                driverId: "driver2",
                status: .activeEnroute,
                stops: [
                    RunStop(
                        type: .pickup,
                        label: "Home",
                        scheduledTime: Date(),
                        requiredPassengerIds: ["2"],
                        location: LocationData(latitude: 37.7749, longitude: -122.4194)
                    )
                ],
                passengers: [
                    MemberSummary(id: "driver2", displayName: "Driver", role: .driver),
                    MemberSummary(id: "2", displayName: "Passenger", role: .passenger)
                ],
                createdBy: "user2",
                familyId: "family1"
            ),
            onTap: {}
        )
        
        CompactRunCard(
            run: Run(
                title: "Completed Run",
                scheduledTime: Date().addingTimeInterval(-3600),
                driverId: "driver3",
                status: .completed,
                stops: [
                    RunStop(
                        type: .pickup,
                        label: "Home",
                        scheduledTime: Date().addingTimeInterval(-3600),
                        requiredPassengerIds: ["3"],
                        location: LocationData(latitude: 37.7749, longitude: -122.4194)
                    )
                ],
                passengers: [
                    MemberSummary(id: "driver3", displayName: "Driver", role: .driver),
                    MemberSummary(id: "3", displayName: "Passenger", role: .passenger)
                ],
                createdBy: "user3",
                familyId: "family1"
            ),
            onTap: {}
        )
        
        CompactRunCard(
            run: Run(
                title: "Delayed Run",
                scheduledTime: Date().addingTimeInterval(1800),
                driverId: "driver4",
                status: .scheduled,
                stops: [
                    RunStop(
                        type: .pickup,
                        label: "Home",
                        scheduledTime: Date().addingTimeInterval(1800),
                        requiredPassengerIds: ["4"],
                        location: LocationData(latitude: 37.7749, longitude: -122.4194)
                    )
                ],
                passengers: [
                    MemberSummary(id: "driver4", displayName: "Driver", role: .driver),
                    MemberSummary(id: "4", displayName: "Passenger", role: .passenger)
                ],
                createdBy: "user4",
                familyId: "family1",
                isDelayed: true,
                delayReason: "Traffic"
            ),
            onTap: {}
        )
    }
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Dark Mode") {
    VStack(spacing: 12) {
        CompactRunCard(
            run: Run(
                title: "Soccer Practice",
                scheduledTime: Date().addingTimeInterval(3600),
                driverId: "driver1",
                status: .scheduled,
                stops: [
                    RunStop(
                        type: .pickup,
                        label: "Home",
                        scheduledTime: Date().addingTimeInterval(3600),
                        requiredPassengerIds: ["1", "2"],
                        location: LocationData(latitude: 37.7749, longitude: -122.4194)
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
            onTap: {}
        )
        
        CompactRunCard(
            run: Run(
                title: "Active Run",
                scheduledTime: Date(),
                driverId: "driver2",
                status: .activeEnroute,
                stops: [
                    RunStop(
                        type: .pickup,
                        label: "Home",
                        scheduledTime: Date(),
                        requiredPassengerIds: ["3"],
                        location: LocationData(latitude: 37.7749, longitude: -122.4194)
                    )
                ],
                passengers: [
                    MemberSummary(id: "driver2", displayName: "Jane Wilson", role: .driver),
                    MemberSummary(id: "3", displayName: "Charlie Brown", role: .passenger)
                ],
                createdBy: "user2",
                familyId: "family1"
            ),
            onTap: {}
        )
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
