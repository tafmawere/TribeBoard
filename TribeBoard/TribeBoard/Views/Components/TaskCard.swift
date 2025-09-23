import SwiftUI

struct TaskCard: View {
    let task: FamilyTask
    let userProfiles: [UUID: UserProfile]
    let canEdit: Bool
    let canComplete: Bool
    let onTap: () -> Void
    let onStatusChange: (FamilyTask.TaskStatus) -> Void
    
    @State private var showingStatusMenu = false
    
    private var assigneeName: String {
        userProfiles[task.assignedTo]?.displayName ?? "Unknown User"
    }
    
    private var assignedByName: String {
        userProfiles[task.assignedBy]?.displayName ?? "Unknown User"
    }
    
    private var isOverdue: Bool {
        guard let dueDate = task.dueDate else { return false }
        return dueDate < Date() && task.status != .completed
    }
    
    private var timeUntilDue: String? {
        guard let dueDate = task.dueDate else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDate(dueDate, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Due today at \(formatter.string(from: dueDate))"
        } else if dueDate < now {
            let components = calendar.dateComponents([.day], from: dueDate, to: now)
            let days = components.day ?? 0
            return days == 1 ? "1 day overdue" : "\(days) days overdue"
        } else {
            let components = calendar.dateComponents([.day], from: now, to: dueDate)
            let days = components.day ?? 0
            return days == 1 ? "Due in 1 day" : "Due in \(days) days"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Main card content
                HStack(spacing: 16) {
                    // Status indicator and category icon
                    VStack(spacing: 8) {
                        // Category icon
                        Text(task.category.icon)
                            .font(.title2)
                        
                        // Status indicator line
                        Rectangle()
                            .fill(colorForStatus(task.status))
                            .frame(width: 4, height: 50)
                            .cornerRadius(2)
                    }
                    
                    // Task details
                    VStack(alignment: .leading, spacing: 8) {
                        // Title and points
                        HStack {
                            Text(task.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            // Points badge
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                
                                Text("\(task.points)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(8)
                        }
                        
                        // Description (if available)
                        if let description = task.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        // Assignee and category info
                        HStack(spacing: 12) {
                            // Assignee
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(assigneeName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Category
                            HStack(spacing: 4) {
                                Image(systemName: "tag")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(task.category.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Due date and status
                        HStack {
                            // Due date info
                            if let timeInfo = timeUntilDue {
                                HStack(spacing: 4) {
                                    Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "clock")
                                        .font(.caption)
                                        .foregroundColor(isOverdue ? .red : .secondary)
                                    
                                    Text(timeInfo)
                                        .font(.caption)
                                        .foregroundColor(isOverdue ? .red : .secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Status badge
                            TaskStatusBadge(status: task.status)
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: 8) {
                        // Quick complete button (if user can complete)
                        if canComplete && task.status != .completed {
                            Button(action: {
                                onStatusChange(.completed)
                            }) {
                                Image(systemName: "checkmark.circle")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Status menu button (if user can edit)
                        if canEdit {
                            Button(action: {
                                showingStatusMenu = true
                            }) {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(backgroundColorForTask)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .confirmationDialog(
            "Change Status",
            isPresented: $showingStatusMenu,
            titleVisibility: .visible
        ) {
            if task.status != .pending {
                Button("Mark as Pending") {
                    onStatusChange(.pending)
                }
            }
            
            if task.status != .inProgress {
                Button("Mark as In Progress") {
                    onStatusChange(.inProgress)
                }
            }
            
            if task.status != .completed {
                Button("Mark as Completed") {
                    onStatusChange(.completed)
                }
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Change the status of '\(task.title)'")
        }
    }
    
    // MARK: - Helper Methods
    
    private func colorForStatus(_ status: FamilyTask.TaskStatus) -> Color {
        switch status {
        case .pending:
            return .gray
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .overdue:
            return .red
        }
    }
    
    private var backgroundColorForTask: Color {
        switch task.status {
        case .completed:
            return Color.green.opacity(0.1)
        case .overdue:
            return Color.red.opacity(0.1)
        default:
            return Color(.systemBackground)
        }
    }
}

// MARK: - Task Status Badge

struct TaskStatusBadge: View {
    let status: FamilyTask.TaskStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColorForStatus)
            .foregroundColor(textColorForStatus)
            .cornerRadius(8)
    }
    
    private var backgroundColorForStatus: Color {
        switch status {
        case .pending:
            return Color.gray.opacity(0.2)
        case .inProgress:
            return Color.blue.opacity(0.2)
        case .completed:
            return Color.green.opacity(0.2)
        case .overdue:
            return Color.red.opacity(0.2)
        }
    }
    
    private var textColorForStatus: Color {
        switch status {
        case .pending:
            return .gray
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .overdue:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    let mockTask = FamilyTask(
        id: UUID(),
        title: "Clean bedroom",
        description: "Tidy up room and make bed",
        assignedTo: UUID(),
        assignedBy: UUID(),
        dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
        status: .pending,
        points: 10,
        category: .chores,
        createdAt: Date()
    )
    
    let mockProfiles = [
        mockTask.assignedTo: UserProfile(displayName: "Ethan Mawere", appleUserIdHash: "hash_ethan"),
        mockTask.assignedBy: UserProfile(displayName: "Tafadzwa Mawere", appleUserIdHash: "hash_tafadzwa")
    ]
    
    return VStack(spacing: 16) {
        TaskCard(
            task: mockTask,
            userProfiles: mockProfiles,
            canEdit: true,
            canComplete: true,
            onTap: { },
            onStatusChange: { _ in }
        )
        
        TaskCard(
            task: FamilyTask(
                id: UUID(),
                title: "Math homework",
                description: "Complete chapter 5 exercises",
                assignedTo: UUID(),
                assignedBy: UUID(),
                dueDate: Date(),
                status: .completed,
                points: 15,
                category: .homework,
                createdAt: Date()
            ),
            userProfiles: mockProfiles,
            canEdit: false,
            canComplete: false,
            onTap: { },
            onStatusChange: { _ in }
        )
    }
    .padding()
}