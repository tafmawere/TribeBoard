//
//  MemberProfileView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Detailed profile screen for a selected family member
struct MemberProfileView: View {
    let member: FamilyMemberDisplay
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingSwitchAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with avatar and name
                    headerSection
                    
                    Divider()
                    
                    // Roles section
                    rolesSection
                    
                    Divider()
                    
                    // Permissions section
                    permissionsSection
                    
                    Divider()
                    
                    // Contact section
                    contactSection
                    
                    Divider()
                    
                    // Run context section
                    runContextSection
                    
                    // Demo: View as this user button
                    if AppConfig.isDemoFlowEnabled {
                        Divider()
                        demoSwitchUserSection
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 80, height: 80)
                
                Text(member.avatarInitials)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(member.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(member.isParent ? "Parent" : "Child")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Roles Section
    
    private var rolesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Roles")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(member.roleBadges, id: \.self) { badge in
                    Text(badge.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(badgeColor(for: badge.color).opacity(0.2))
                        .foregroundColor(badgeColor(for: badge.color))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Permissions Section
    
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(member.capabilities, id: \.self) { capability in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(capability)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
    
    // MARK: - Contact Section
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact")
                .font(.headline)
            
            if let phone = member.phone {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.blue)
                    
                    Text(phone)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    // Call button for drivers
                    if member.roleBadges.contains(where: { $0.name == "Driver" }) {
                        Button(action: {
                            if let url = URL(string: "tel://\(phone.filter { $0.isNumber })") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Call Driver")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
            } else {
                Text("No contact information")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Run Context Section
    
    private var runContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run Context")
                .font(.headline)
            
            let runStats = viewModel.getRunStats(for: member.id)
            
            VStack(alignment: .leading, spacing: 8) {
                if member.roleBadges.contains(where: { $0.name == "Driver" }) {
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.blue)
                        Text("Assigned runs: \(runStats.assignedRuns)")
                            .font(.subheadline)
                    }
                }
                
                HStack {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.green)
                    Text("Visible runs: \(runStats.visibleRuns)")
                        .font(.subheadline)
                }
            }
        }
    }
    
    // MARK: - Demo Switch User Section
    
    private var demoSwitchUserSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Demo Only")
                .font(.headline)
                .foregroundColor(.orange)
            
            Button(action: {
                showingSwitchAlert = true
            }) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("View as this user")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(10)
            }
            
            Text("This will switch the current user to \(member.displayName) and update the My Runs view.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helpers
    
    private var avatarColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .indigo]
        let index = abs(member.id.hashValue) % colors.count
        return colors[index]
    }
    
    private func badgeColor(for color: FamilyMemberDisplay.RoleBadge.BadgeColor) -> Color {
        switch color {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        }
    }
}

/// Simple flow layout for wrapping badges
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
