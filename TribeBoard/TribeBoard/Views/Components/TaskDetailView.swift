import SwiftUI

struct TaskDetailView: View {
    let task: FamilyTask
    let userProfiles: [UUID: UserProfile]
    let canEdit: Bool
    let canComplete: Bool
    let onStatusChange: (FamilyTask.TaskStatus) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingStatusMenu = false
    
    private var assigneeName: String {
        userProfiles[task.assignedTo]?.displayName ?? "Unknown User"
    }
    
    private var assignedByName: String {
        userProfiles[task.assignedBy]?.displayName ?? "Unknown User"
    }
    
    private var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: task.createdAt)
    }
    
    private var formattedDueDate: String? {
        guard let dueDate = task.dueDate else { return nil }
        
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(dueDate, inSameDayAs: Date()) {
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: dueDate))"
        } else if calendar.isDateInTomorrow(dueDate) {
            formatter.timeStyle = .short
            return "Tomorrow at \(formatter.string(from: dueDate))"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: dueDate)
        }
    }
    
    private var isOverdue: Bool {
        guard let dueDate = task.dueDate else { return false }
        return dueDate < Date() && task.status != .completed
    }
    
    private var timeUntilDue: String? {
        guard let dueDate = task.dueDate else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        
        if dueDate < now && task.status != .completed {
            let components = calendar.dateComponents([.day, .hour], from: dueDate, to: now)
            if let days = components.day, days > 0 {
                return "\(days) day\(days == 1 ? "" : "s") overdue"
            } else if let hours = components.hour, hours > 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s") overdue"
            } else {
                return "Just overdue"
            }
        } else if dueDate > now {
            let components = calendar.dateComponents([.day, .hour], from: now, to: dueDate)
            if let days = components.day, days > 0 {
                return "Due in \(days) day\(days == 1 ? "" : "s")"
            } else if let hours = components.hour, hours > 0 {
                return "Due in \(hours) hour\(hours == 1 ? "" : "s")"
            } else {
                return "Due very soon"
            }
        }
        
        return nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Task header
                    taskHeaderView
                    
                    // Task details
                    taskDetailsView
                    
                    // Assignment info
                    assignmentInfoView
                    
                    // Timeline info
                    timelineInfoView
                    
                    // Action buttons
                    if canEdit || canComplete {
                        actionButtonsView
                    }
                }
                .padding()
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if canEdit {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Change Status") {
                                showingStatusMenu = true
                            }
                            
                            Divider()
                            
                            Button("Delete Task", role: .destructive) {
                                showingDeleteConfirmation = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Change Status",
            isPresented: $showingStatusMenu,
            titleVisibility: .visible
        ) {
            if task.status != .pending {
                Button("Mark as Pending") {
                    onStatusChange(.pending)
                    dismiss()
                }
            }
            
            if task.status != .inProgress {
                Button("Mark as In Progress") {
                    onStatusChange(.inProgress)
                    dismiss()
                }
            }
            
            if task.status != .completed {
                Button("Mark as Completed") {
                    onStatusChange(.completed)
                    dismiss()
                }
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Change the status of this task")
        }
        .alert("Delete Task", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(task.title)'? This action cannot be undone.")
        }
    }
    
    // MARK: - View Components
    
    private var taskHeaderView: some View {
        VStack(spacing: 16) {
            // Category and status
            HStack {
                HStack(spacing: 8) {
                    Text(task.category.icon)
                        .font(.title)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.category.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TaskStatusBadge(status: task.status)
                    }
                }
                
                Spacer()
                
                // Points display
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundColor(.yellow)
                        
                        Text("\(task.points)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Task title
            Text(task.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var taskDetailsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let description = task.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("No description provided")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var assignmentInfoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assignment")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Assigned to
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Assigned to")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(assigneeName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                
                // Assigned by
                HStack {
                    Image(systemName: "person.badge.plus")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Assigned by")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(assignedByName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var timelineInfoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeline")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Created date
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Created")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formattedCreatedDate)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                
                // Due date (if set)
                if let dueDate = formattedDueDate {
                    HStack {
                        Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "clock.fill")
                            .font(.title2)
                            .foregroundColor(isOverdue ? .red : .orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Due date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(dueDate)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(isOverdue ? .red : .primary)
                            
                            if let timeInfo = timeUntilDue {
                                Text(timeInfo)
                                    .font(.caption)
                                    .foregroundColor(isOverdue ? .red : .secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            if canComplete && task.status != .completed {
                Button("Mark as Completed") {
                    onStatusChange(.completed)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            
            if canEdit && task.status == .pending {
                Button("Start Working") {
                    onStatusChange(.inProgress)
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let mockTask = FamilyTask(
        id: UUID(),
        title: "Clean bedroom and organize desk",
        description: "Tidy up the entire room, make the bed, and organize all items on the desk. Put away any clothes and vacuum the floor.",
        assignedTo: UUID(),
        assignedBy: UUID(),
        dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
        status: .inProgress,
        points: 15,
        category: .chores,
        createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
    )
    
    let mockProfiles = [
        mockTask.assignedTo: UserProfile(displayName: "Ethan Mawere", appleUserIdHash: "hash_ethan"),
        mockTask.assignedBy: UserProfile(displayName: "Tafadzwa Mawere", appleUserIdHash: "hash_tafadzwa")
    ]
    
    return TaskDetailView(
        task: mockTask,
        userProfiles: mockProfiles,
        canEdit: true,
        canComplete: true,
        onStatusChange: { _ in },
        onDelete: { }
    )
}