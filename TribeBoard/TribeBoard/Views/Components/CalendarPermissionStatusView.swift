import SwiftUI
import SwiftData

/// View for displaying calendar permission status for family members
struct CalendarPermissionStatusView: View {
    let permission: CalendarPermission
    let isCurrentUser: Bool
    let onEditPermission: (() -> Void)?
    
    @State private var showingPermissionDetails = false
    
    init(
        permission: CalendarPermission,
        isCurrentUser: Bool = false,
        onEditPermission: (() -> Void)? = nil
    ) {
        self.permission = permission
        self.isCurrentUser = isCurrentUser
        self.onEditPermission = onEditPermission
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with permission level
            HStack {
                permissionLevelBadge
                
                Spacer()
                
                if isCurrentUser {
                    Text("You")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                
                if onEditPermission != nil {
                    Button("Edit") {
                        onEditPermission?()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Permission description
            Text(permission.permissionLevel.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            // Effective permissions summary
            if !permission.effectivePermissions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: {
                        showingPermissionDetails.toggle()
                    }) {
                        HStack {
                            Text("Permissions (\(permission.effectivePermissions.count))")
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Image(systemName: showingPermissionDetails ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if showingPermissionDetails {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 4) {
                            ForEach(permission.effectivePermissions, id: \.self) { perm in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    
                                    Text(perm.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            
            // Last modified info
            HStack {
                Text("Updated \(permission.lastModified, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    private var permissionLevelBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: permission.permissionLevel.icon)
                .font(.caption)
                .foregroundColor(Color(permission.permissionLevel.color))
            
            Text(permission.permissionLevel.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(permission.permissionLevel.color).opacity(0.1))
        .cornerRadius(8)
    }
    
    private var accessibilityLabel: String {
        let userLabel = isCurrentUser ? "Your calendar permission" : "Calendar permission"
        return "\(userLabel): \(permission.permissionLevel.displayName)"
    }
    
    private var accessibilityHint: String {
        if onEditPermission != nil {
            return "Double tap to edit permissions"
        } else {
            return "Double tap to view permission details"
        }
    }
}

/// View for displaying a summary of all family calendar permissions
struct FamilyCalendarPermissionsView: View {
    let familyId: UUID
    let currentUserId: UUID
    let canManagePermissions: Bool
    
    @StateObject private var permissionManager: CalendarPermissionManager
    @State private var permissions: [CalendarPermission] = []
    @State private var permissionStatus: FamilyPermissionStatus?
    @State private var showingPermissionEditor = false
    @State private var selectedPermission: CalendarPermission?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    init(
        familyId: UUID,
        currentUserId: UUID,
        canManagePermissions: Bool,
        modelContext: ModelContext
    ) {
        self.familyId = familyId
        self.currentUserId = currentUserId
        self.canManagePermissions = canManagePermissions
        self._permissionManager = StateObject(wrappedValue: CalendarPermissionManager(modelContext: modelContext))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Calendar Permissions")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let status = permissionStatus {
                        Text("\(status.totalMembers) members with calendar access")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if canManagePermissions {
                    Button("Manage All") {
                        showingPermissionEditor = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if isLoading {
                ProgressView("Loading permissions...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let errorMessage = errorMessage {
                ErrorStateView(
                    title: "Permission Error",
                    message: errorMessage,
                    retryAction: loadPermissions
                )
            } else if permissions.isEmpty {
                EmptyStateView(
                    icon: "person.2.slash",
                    title: "No Calendar Permissions",
                    message: "No family members have calendar access configured."
                )
            } else {
                // Permission status summary
                if let status = permissionStatus {
                    permissionSummaryView(status)
                }
                
                // Individual permissions
                LazyVStack(spacing: 12) {
                    ForEach(permissions, id: \.id) { permission in
                        CalendarPermissionStatusView(
                            permission: permission,
                            isCurrentUser: permission.userId == currentUserId,
                            onEditPermission: canManagePermissions ? {
                                selectedPermission = permission
                                showingPermissionEditor = true
                            } : nil
                        )
                    }
                }
            }
        }
        .onAppear {
            loadPermissions()
        }
        .sheet(isPresented: $showingPermissionEditor) {
            CalendarPermissionEditorView(
                familyId: familyId,
                currentUserId: currentUserId,
                editingPermission: selectedPermission,
                permissionManager: permissionManager
            ) {
                loadPermissions()
                selectedPermission = nil
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Family calendar permissions")
    }
    
    private func permissionSummaryView(_ status: FamilyPermissionStatus) -> some View {
        HStack(spacing: 16) {
            permissionCountBadge("Admins", count: status.adminCount, color: .purple)
            permissionCountBadge("Editors", count: status.editorCount, color: .blue)
            permissionCountBadge("Viewers", count: status.viewerCount, color: .green)
            
            if status.noAccessCount > 0 {
                permissionCountBadge("No Access", count: status.noAccessCount, color: .gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func permissionCountBadge(_ title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func loadPermissions() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedPermissions = try permissionManager.getPermissions(for: familyId)
                let status = try permissionManager.getPermissionStatus(for: familyId)
                
                await MainActor.run {
                    self.permissions = fetchedPermissions
                    self.permissionStatus = status
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CalendarPermission.self, configurations: config)
    
    // Create sample permission
    let permission = CalendarPermission(
        userId: UUID(),
        familyId: UUID(),
        permissionLevel: .editor,
        grantedBy: UUID(),
        specificPermissions: [.createEvents, .editOwnEvents, .viewFamilyEvents]
    )
    
    return CalendarPermissionStatusView(
        permission: permission,
        isCurrentUser: true,
        onEditPermission: {}
    )
    .padding()
}