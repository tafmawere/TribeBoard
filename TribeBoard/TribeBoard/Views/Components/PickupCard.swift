import SwiftUI
import Foundation

/// Card component showing driver and passenger information for school runs
struct PickupCard: View {
    let schoolRun: SchoolRun
    let userProfiles: [UUID: UserProfile]
    let onTrackRoute: () -> Void
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with route and status
            headerSection
            
            // Time and participants info
            detailsSection
            
            // Action buttons
            actionsSection
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            // Route icon and status indicator
            HStack(spacing: 8) {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundColor(statusColor)
                
                Rectangle()
                    .fill(statusColor)
                    .frame(width: 4, height: 40)
                    .cornerRadius(2)
            }
            
            // Route information
            VStack(alignment: .leading, spacing: 4) {
                Text(schoolRun.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.caption)
                        .foregroundColor(statusColor)
                    
                    Text(schoolRun.status.displayText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                }
            }
            
            Spacer()
            
            // Status badge
            statusBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(statusColor.opacity(0.05))
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(spacing: 12) {
            // Time information
            timeInfoSection
            
            Divider()
            
            // Driver and passengers
            participantsSection
            
            // Notes section (using title as notes for now)
            if !schoolRun.title.isEmpty {
                notesSection(schoolRun.title)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var timeInfoSection: some View {
        HStack(spacing: 16) {
            // Pickup time
            VStack(alignment: .leading, spacing: 2) {
                Text("Pickup")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(timeFormatter.string(from: schoolRun.pickupStops.first?.time ?? schoolRun.date))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            // Arrow
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Drop-off time
            VStack(alignment: .leading, spacing: 2) {
                Text("Drop-off")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(timeFormatter.string(from: schoolRun.dropoffStops.last?.time ?? schoolRun.date))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // Duration
            VStack(alignment: .trailing, spacing: 2) {
                Text("Duration")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(durationText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
    }
    
    private var participantsSection: some View {
        VStack(spacing: 8) {
            // Driver
            driverSection
            
            // Passengers
            if !schoolRun.participatingChildren.isEmpty {
                passengersSection
            }
        }
    }
    
    private var driverSection: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title3)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Driver")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(driverName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
    
    private var passengersSection: some View {
        HStack {
            Image(systemName: "person.2.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Passengers")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(passengersText)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
    
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            
            HStack {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text(notes)
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        HStack(spacing: 12) {
            // Track Route button
            if schoolRun.status == .scheduled || schoolRun.status == .inProgress {
                Button(action: onTrackRoute) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text("Track Route")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
            
            Spacer()
            
            // Additional action buttons based on status
            statusActionButtons
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var statusActionButtons: some View {
        switch schoolRun.status {
        case .scheduled:
            Button("Start Run") {
                // Mock action - would start the run
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.blue)
            
        case .inProgress:
            Button("Complete") {
                // Mock action - would complete the run
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.green)
            
        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                Text("Completed")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
        case .cancelled:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                Text("Cancelled")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Status Badge
    
    private var statusBadge: some View {
        Text(schoolRun.status.displayText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch schoolRun.status {
        case .scheduled:
            return .blue
        case .inProgress:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
    
    private var statusIcon: String {
        switch schoolRun.status {
        case .scheduled:
            return "clock"
        case .inProgress:
            return "location.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
    
    private var driverName: String {
        // Driver not implemented in SchoolRun model yet
        "Driver TBD"
    }
    
    private var passengersText: String {
        let passengerNames = schoolRun.participatingChildren
        
        if passengerNames.isEmpty {
            return "No passengers"
        } else if passengerNames.count == 1 {
            return passengerNames[0]
        } else if passengerNames.count == 2 {
            return "\(passengerNames[0]) and \(passengerNames[1])"
        } else {
            return "\(passengerNames[0]) and \(passengerNames.count - 1) others"
        }
    }
    
    private var durationText: String {
        // Use the estimated duration from the SchoolRun model
        return schoolRun.formattedDuration
    }
}

// MARK: - Preview

#Preview {
    // Note: This preview is temporarily disabled due to SchoolRun model changes
    // The PickupCard component needs to be updated to work with the new SchoolRun structure
    Text("PickupCard Preview")
        .foregroundColor(.secondary)
        .padding()
}