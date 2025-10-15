import SwiftUI
import SwiftData

/// View for managing family calendar permissions and settings
struct FamilyCalendarManagementView: View {
    let family: Family
    let currentUserId: UUID
    
    @StateObject private var permissionManager: CalendarPermissionManager
    @State private var permissions: [CalendarPermission] = []
    @State private var permissionStatus: FamilyPermissionStatus?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingBulkEditor = false
    @State private var showingPermissionEditor = false
    @State private var selectedPermission: CalendarPermission?
    
    private var canManagePermissions: Bool {
        guard let permission = permissions.first(where: { $0.userId == currentUserId }) else {
            return false
        }
        return permission.hasPermission(.managePermissions)
    }
    
    init(family: Family, currentUserId: UUID, modelContext: ModelContext) {
        self.family = family
        self.currentUserId = currentUserId
        self._permissionManager = StateObject(wrappedValue: CalendarPermissionManager(modelContext: modelContext))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            headerSection
            
            if isLoading {
                loadingSection
            } else if let errorMessage = errorMessage {
                errorSection(errorMessage)
            } else {
                // Permission overview
                if let status = permissionStatus {
                    permissionOverviewSection(status)
                }
                
                // Individual permissions
                permissionsListSection
                
                // Management actions
                if canManagePermissions {
                    managementActionsSection
                }
            }
        }
        .onAppear {
            loadPermissions()
        }
        .sheet(isPresented: $showingPermissionEditor) {
            CalendarPermissionEditorView(
                familyId: family.id,
                currentUserId: currentUserId,
                editingPermission: selectedPermission,
                permissionManager: permissionManager
            ) {
                loadPermissions()
                selectedPermission = nil
            }
        }
        .sheet(isPresented: $showingBulkEditor) {
            BulkCalendarPermissionView(
                familyId: family.id,
                currentUserId: currentUserId,
                permissionManager: permissionManager
            ) {
                loadPermissions()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Calendar Management")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if canManagePermissions {
                    Menu {
                        Button("Add Permission") {
                            selectedPermission = nil
                            showingPermissionEditor = true
                        }
                        
                        Button("Bulk Edit") {
                            showingBulkEditor = true
                        }
                        
                        Divider()
                        
                        Button("Reset to Defaults") {
                            resetToDefaultPermissions()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Text("Manage who can create, edit, and delete family calendar events")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading calendar permissions...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(.orange)
            
            Text("Permission Error")
                .font(.headline)
                .fontWeight(.medium)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                loadPermissions()
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func permissionOverviewSection(_ status: FamilyPermissionStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permission Overview")
                .font(.headline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                permissionStatCard("Admins", count: status.adminCount, color: .purple, icon: "crown.fill")
                permissionStatCard("Editors", count: status.editorCount, color: .blue, icon: "pencil.circle.fill")
                permissionStatCard("Viewers", count: status.viewerCount, color: .green, icon: "eye.fill")
            }
            
            if !status.hasAdmins {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("No calendar administrators assigned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func permissionStatCard(_ title: String, count: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var permissionsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Member Permissions")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(permissions.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if permissions.isEmpty {
                EmptyStateView(
                    icon: "person.2.slash",
                    title: "No Permissions Set",
                    message: "No family members have calendar permissions configured."
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(permissions, id: \.id) { permission in
                        CalendarPermissionRowView(
                            permission: permission,
                            isCurrentUser: permission.userId == currentUserId,
                            canEdit: canManagePermissions,
                            onEdit: {
                                selectedPermission = permission
                                showingPermissionEditor = true
                            },
                            onRevoke: {
                                revokePermission(permission)
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var managementActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Management Actions")
                .font(.headline)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                Button(action: {
                    selectedPermission = nil
                    showingPermissionEditor = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        
                        Text("Grant Calendar Permission")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingBulkEditor = true
                }) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.purple)
                        
                        Text("Bulk Permission Update")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func loadPermissions() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedPermissions = try permissionManager.getPermissions(for: family.id)
                let status = try permissionManager.getPermissionStatus(for: family.id)
                
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
    
    private func revokePermission(_ permission: CalendarPermission) {
        Task {
            do {
                try permissionManager.revokePermission(
                    from: permission.userId,
                    in: family.id,
                    revokedBy: currentUserId
                )
                
                await MainActor.run {
                    loadPermissions()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func resetToDefaultPermissions() {
        // This would reset all permissions to defaults based on family roles
        Task {
            do {
                // Implementation would fetch family memberships and reset permissions
                // For now, just reload
                await MainActor.run {
                    loadPermissions()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

/// Individual permission row view
struct CalendarPermissionRowView: View {
    let permission: CalendarPermission
    let isCurrentUser: Bool
    let canEdit: Bool
    let onEdit: () -> Void
    let onRevoke: () -> Void
    
    @State private var showingRevokeConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Permission level indicator
            VStack {
                Image(systemName: permission.permissionLevel.icon)
                    .font(.title3)
                    .foregroundColor(Color(permission.permissionLevel.color))
                    .frame(width: 24, height: 24)
            }
            
            // User info and permission details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("User \(permission.userId.uuidString.prefix(8))...")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text(permission.permissionLevel.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if permission.effectivePermissions.count > 0 {
                    Text("\(permission.effectivePermissions.count) permissions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Actions
            if canEdit {
                HStack(spacing: 8) {
                    Button("Edit") {
                        onEdit()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    if permission.permissionLevel != .admin || !isCurrentUser {
                        Button("Revoke") {
                            showingRevokeConfirmation = true
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .alert("Revoke Permission", isPresented: $showingRevokeConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Revoke", role: .destructive) {
                onRevoke()
            }
        } message: {
            Text("Are you sure you want to revoke calendar permissions for this family member?")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Family.self, CalendarPermission.self, configurations: config)
    
    let family = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
    
    return FamilyCalendarManagementView(
        family: family,
        currentUserId: UUID(),
        modelContext: container.mainContext
    )
    .padding()
}