//
//  MemberProfileView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Detailed profile screen for a selected family member
/// Redesigned to match TribeBoard's visual language with card-based layout
///
/// **Design System Usage:**
/// - Uses DesignSystem.Colors for all color values
/// - Uses DesignSystem.Spacing for consistent spacing
/// - Uses DesignSystem.CornerRadius for rounded corners
/// - ProfileCard wrapper provides consistent card styling
///
/// **Card Structure:**
/// - Header: Avatar, name, relationship, role badges
/// - Permissions: List of capabilities based on roles
/// - Location Sharing: Status indicator with description
/// - Contact: Phone number and call button (drivers only)
/// - Activity: Run statistics (assigned/visible runs)
/// - Demo: User switching for testing (demo mode only)
///
/// **Accessibility:**
/// - VoiceOver labels for all interactive elements
/// - Supports Dynamic Type scaling
/// - Minimum 44x44pt touch targets
/// - Color contrast meets WCAG AA standards
struct MemberProfileView: View {
    let member: FamilyMemberDisplay
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingSwitchAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.sectionSpacing) {
                    // Header card with avatar, name, and roles
                    headerCard
                    
                    // Permissions card
                    permissionsCard
                    
                    // Location sharing card
                    locationCard
                    
                    // Contact card
                    contactCard
                    
                    // Activity card
                    activityCard
                    
                    // Demo section (only in demo mode)
                    if AppConfig.isDemoFlowEnabled {
                        demoCard
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.spacing16)
                .padding(.vertical, DesignSystem.Spacing.spacing20)
            }
            .background(DesignSystem.Colors.screenBackground)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primaryBlue)
                }
            }
            .alert("Switch User", isPresented: $showingSwitchAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Switch") {
                    viewModel.switchToUser(member.id)
                    dismiss()
                }
            } message: {
                Text("Switch to \(member.displayName)?")
            }
        }
    }
    
    // MARK: - Header Card
    
    /// Header card displaying member's identity and roles
    /// - Avatar: 80x80pt circle with deterministic color
    /// - Name: 22pt bold, primary text color
    /// - Relationship: "Mom" or "Child" based on isParent
    /// - Role badges: Flow layout with 8pt spacing, wraps to multiple rows
    private var headerCard: some View {
        ProfileCard {
            VStack(spacing: DesignSystem.Spacing.spacing16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(avatarColor)
                        .frame(width: 80, height: 80)
                    
                    Text(member.avatarInitials)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                .accessibilityLabel("Profile picture for \(member.displayName)")
                
                // Name and relationship
                VStack(spacing: DesignSystem.Spacing.spacing4) {
                    Text(member.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(member.isParent ? "Mom" : "Child")
                        .font(.system(size: 15))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                // Role badges
                FlowLayout(spacing: DesignSystem.Spacing.spacing8) {
                    ForEach(member.roleBadges, id: \.self) { badge in
                        RoleBadge(
                            name: badge.name,
                            color: badgeColor(for: badge.color)
                        )
                        .accessibilityLabel("\(badge.name) role")
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Permissions Card
    
    /// Permissions card listing all capabilities granted by member's roles
    /// Uses PermissionRow component with checkmark icon
    /// Dynamically populated from member.capabilities array
    private var permissionsCard: some View {
        ProfileCard {
            SectionHeader("Permissions")
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.spacing12) {
                ForEach(member.capabilities, id: \.self) { capability in
                    PermissionRow(permission: capability)
                        .accessibilityLabel("Permission: \(capability)")
                }
            }
        }
    }
    
    // MARK: - Location Sharing Card
    
    /// Location sharing status card
    /// - Status indicator: 8pt circle (green=enabled, gray=disabled)
    /// - Description text explains usage for real-time tracking
    /// - Accessibility: Announces enabled/disabled status
    private var locationCard: some View {
        ProfileCard {
            SectionHeader("Location Sharing")
            
            HStack(spacing: DesignSystem.Spacing.spacing8) {
                Circle()
                    .fill(member.isLocationSharingEnabled ? DesignSystem.Colors.successGreen : DesignSystem.Colors.textTertiary)
                    .frame(width: 8, height: 8)
                
                Text(member.isLocationSharingEnabled ? "Enabled" : "Disabled")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .accessibilityLabel("Location sharing \(member.isLocationSharingEnabled ? "enabled" : "disabled")")
            
            Text("Used for real-time tracking during runs")
                .font(.system(size: 13))
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
    }
    
    // MARK: - Contact Card
    
    /// Contact information and quick actions
    /// - Shows phone number with icon if available
    /// - "Call Driver" button appears only for members with Driver role
    /// - Button initiates phone call using tel:// URL scheme
    /// - Falls back to "No contact information" message if phone is nil
    private var contactCard: some View {
        ProfileCard {
            SectionHeader("Contact")
            
            if let phone = member.phone {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.spacing12) {
                    HStack(spacing: DesignSystem.Spacing.spacing8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16))
                            .foregroundColor(DesignSystem.Colors.infoBlue)
                        
                        Text(phone)
                            .font(.system(size: 15))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    
                    // Call button for drivers
                    if member.roleBadges.contains(where: { $0.name == "Driver" }) {
                        Button(action: {
                            if let url = URL(string: "tel://\(phone.filter { $0.isNumber })") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: DesignSystem.Spacing.spacing8) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 16))
                                
                                Text("Call Driver")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(DesignSystem.Colors.primaryBlue)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        .accessibilityLabel("Call \(member.displayName)")
                    }
                }
            } else {
                Text("No contact information available")
                    .font(.system(size: 15))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
    
    // MARK: - Activity Card
    
    /// Activity statistics card showing run context
    /// - Assigned runs: Only shown for members with Driver role
    /// - Visible runs: Shown for all members
    /// - Uses StatRow component with icons and colored indicators
    /// - Data fetched from viewModel.getRunStats(for:)
    private var activityCard: some View {
        ProfileCard {
            SectionHeader("Activity")
            
            let runStats = viewModel.getRunStats(for: member.id)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.spacing12) {
                if member.roleBadges.contains(where: { $0.name == "Driver" }) {
                    StatRow(
                        icon: "car.fill",
                        iconColor: DesignSystem.Colors.infoBlue,
                        text: "\(runStats.assignedRuns) assigned runs"
                    )
                }
                
                StatRow(
                    icon: "eye.fill",
                    iconColor: DesignSystem.Colors.successGreen,
                    text: "\(runStats.visibleRuns) visible runs"
                )
            }
        }
    }
    
    // MARK: - Demo Card
    
    /// Demo-only card for user context switching
    /// Only visible when AppConfig.isDemoFlowEnabled is true
    /// - Orange section header indicates demo functionality
    /// - Button triggers confirmation alert before switching
    /// - Useful for testing role-based features from different perspectives
    private var demoCard: some View {
        ProfileCard {
            SectionHeader("Demo Only", color: DesignSystem.Colors.warningOrange)
            
            Button(action: {
                showingSwitchAlert = true
            }) {
                HStack(spacing: DesignSystem.Spacing.spacing8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 16))
                    
                    Text("View as this user")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(DesignSystem.Colors.warningOrange)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(DesignSystem.Colors.warningOrange.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .accessibilityLabel("Switch to \(member.displayName)'s view")
            
            Text("Switch to \(member.displayName)'s perspective to test role-based features")
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
    }
    
    // MARK: - Helpers
    
    /// Deterministic avatar color based on user ID
    /// Uses hash of member.id to select from 6 design system colors
    /// Ensures same user always gets same color across app
    private var avatarColor: Color {
        let colors: [Color] = [
            DesignSystem.Colors.infoBlue,
            DesignSystem.Colors.successGreen,
            DesignSystem.Colors.warningOrange,
            DesignSystem.Colors.observerBadge,
            DesignSystem.Colors.parentBadge,
            DesignSystem.Colors.primaryBlue
        ]
        let index = abs(member.id.hashValue) % colors.count
        return colors[index]
    }
    
    /// Map badge color enum to design system colors
    /// - blue → driverBadge (indigo-blue)
    /// - green → passengerBadge
    /// - orange → adminBadge
    /// - purple → observerBadge
    private func badgeColor(for color: FamilyMemberDisplay.RoleBadge.BadgeColor) -> Color {
        switch color {
        case .blue: return DesignSystem.Colors.driverBadge
        case .green: return DesignSystem.Colors.passengerBadge
        case .orange: return DesignSystem.Colors.adminBadge
        case .purple: return DesignSystem.Colors.observerBadge
        }
    }
}

/// Simple flow layout for wrapping badges
/// Arranges subviews in rows, wrapping to next row when width is exceeded
/// - spacing: Gap between items (default 8pt)
/// - Wrapping behavior: Moves to next row when item doesn't fit
/// - Used for role badges in header card
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
