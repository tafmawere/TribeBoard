import SwiftUI
import SwiftData

/// View for editing calendar permissions for family members
struct CalendarPermissionEditorView: View {
    let familyId: UUID
    let currentUserId: UUID
    let editingPermission: CalendarPermission?
    let permissionManager: CalendarPermissionManager
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPermissionLevel: CalendarPermissionLevel = .viewer
    @State private var selectedSpecificPermissions: Set<CalendarPermissionType> = []
    @State private var familyMembers: [Membership] = []
    @State private var selectedMemberId: UUID?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingConfirmation = false
    
    private var isEditing: Bool {
        editingPermission != nil
    }
    
    private var canSave: Bool {
        if isEditing {
            return true // Can always save changes to existing permission
        } else {
            return selectedMemberId != nil // Need to select a member for new permission
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                if !isEditing {
                    memberSelectionSection
                }
                
                permissionLevelSection
                specificPermissionsSection
                
                if isEditing {
                    permissionInfoSection
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Permission" : "Grant Permission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Grant") {
                        if isEditing {
                            updatePermission()
                        } else {
                            grantPermission()
                        }
                    }
                    .disabled(!canSave || isLoading)
                }
            }
            .onAppear {
                setupInitialState()
                loadFamilyMembers()
            }
            .alert("Confirm Permission Change", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Confirm") {
                    if isEditing {
                        updatePermission()
                    } else {
                        grantPermission()
                    }
                }
            } message: {
                Text("Are you sure you want to change calendar permissions for this family member?")
            }
        }
    }
    
    private var memberSelectionSection: some View {
        Section("Select Family Member") {
            if familyMembers.isEmpty {
                Text("Loading family members...")
                    .foregroundColor(.secondary)
            } else {
                ForEach(familyMembers, id: \.id) { member in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(member.userDisplayName)
                                .font(.body)
                            
                            Text(member.role.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedMemberId == member.userId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMemberId = member.userId
                        // Set default permission level based on role
                        selectedPermissionLevel = CalendarPermissionLevel.defaultForRole(member.role)
                        updateSpecificPermissionsForLevel()
                    }
                }
            }
        }
    }
    
    private var permissionLevelSection: some View {
        Section("Permission Level") {
            ForEach(CalendarPermissionLevel.allCases, id: \.self) { level in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: level.icon)
                                .foregroundColor(Color(level.color))
                            
                            Text(level.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Text(level.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    if selectedPermissionLevel == level {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedPermissionLevel = level
                    updateSpecificPermissionsForLevel()
                }
            }
        }
    }
    
    private var specificPermissionsSection: some View {
        Section("Specific Permissions") {
            Text("Additional permissions beyond the selected level")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(CalendarPermissionType.allCases, id: \.self) { permission in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(permission.displayName)
                            .font(.body)
                        
                        Text(permission.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { selectedSpecificPermissions.contains(permission) },
                        set: { isSelected in
                            if isSelected {
                                selectedSpecificPermissions.insert(permission)
                            } else {
                                selectedSpecificPermissions.remove(permission)
                            }
                        }
                    ))
                }
            }
        }
    }
    
    private var permissionInfoSection: some View {
        Section("Permission Information") {
            if let permission = editingPermission {
                HStack {
                    Text("Granted")
                    Spacer()
                    Text(permission.grantedAt, style: .date)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Last Modified")
                    Spacer()
                    Text(permission.lastModified, style: .relative)
                        .foregroundColor(.secondary)
                }
                
                if permission.permissionLevel == .admin {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        Text("Admin permissions include all calendar management capabilities")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func setupInitialState() {
        if let permission = editingPermission {
            selectedPermissionLevel = permission.permissionLevel
            selectedSpecificPermissions = Set(permission.specificPermissionsArray)
        }
    }
    
    private func loadFamilyMembers() {
        // This would typically fetch from the data service
        // For now, we'll simulate loading
        Task {
            // Simulate loading delay
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                // In a real implementation, this would fetch actual family members
                // who don't already have calendar permissions
                familyMembers = []
            }
        }
    }
    
    private func updateSpecificPermissionsForLevel() {
        // Clear specific permissions when changing level
        // The effective permissions will be calculated based on the level
        selectedSpecificPermissions.removeAll()
    }
    
    private func grantPermission() {
        guard let memberId = selectedMemberId else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try permissionManager.grantPermission(
                    to: memberId,
                    in: familyId,
                    level: selectedPermissionLevel,
                    grantedBy: currentUserId,
                    specificPermissions: Array(selectedSpecificPermissions)
                )
                
                await MainActor.run {
                    onSave()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func updatePermission() {
        guard let permission = editingPermission else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Update permission level
                try permissionManager.grantPermission(
                    to: permission.userId,
                    in: familyId,
                    level: selectedPermissionLevel,
                    grantedBy: currentUserId,
                    specificPermissions: Array(selectedSpecificPermissions)
                )
                
                await MainActor.run {
                    onSave()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

/// View for bulk permission management
struct BulkCalendarPermissionView: View {
    let familyId: UUID
    let currentUserId: UUID
    let permissionManager: CalendarPermissionManager
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var familyMembers: [Membership] = []
    @State private var permissionUpdates: [UUID: CalendarPermissionLevel] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Bulk Permission Update") {
                    Text("Select permission levels for multiple family members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Family Members") {
                    ForEach(familyMembers, id: \.id) { member in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(member.userDisplayName)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text(member.role.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(6)
                            }
                            
                            Picker("Permission Level", selection: Binding(
                                get: { permissionUpdates[member.userId] ?? .viewer },
                                set: { permissionUpdates[member.userId] = $0 }
                            )) {
                                ForEach(CalendarPermissionLevel.allCases, id: \.self) { level in
                                    Text(level.displayName).tag(level)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Bulk Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyBulkUpdates()
                    }
                    .disabled(isLoading || permissionUpdates.isEmpty)
                }
            }
            .onAppear {
                loadFamilyMembers()
            }
        }
    }
    
    private func loadFamilyMembers() {
        // Load family members and their current permissions
        Task {
            // Simulate loading
            await MainActor.run {
                // In real implementation, fetch actual family members
                familyMembers = []
            }
        }
    }
    
    private func applyBulkUpdates() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let updates = permissionUpdates.map { (userId, level) in
                    BulkPermissionUpdate(
                        userId: userId,
                        action: .grant,
                        permissionLevel: level,
                        specificPermissions: []
                    )
                }
                
                try permissionManager.bulkUpdatePermissions(
                    updates: updates,
                    familyId: familyId,
                    updatedBy: currentUserId
                )
                
                await MainActor.run {
                    onComplete()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CalendarPermission.self, configurations: config)
    let context = container.mainContext
    
    return CalendarPermissionEditorView(
        familyId: UUID(),
        currentUserId: UUID(),
        editingPermission: nil,
        permissionManager: CalendarPermissionManager(modelContext: context),
        onSave: {}
    )
}