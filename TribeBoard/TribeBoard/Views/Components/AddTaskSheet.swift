import SwiftUI

struct AddTaskSheet: View {
    let userProfiles: [UUID: UserProfile]
    let onTaskCreated: (String, FamilyTask.TaskCategory, UUID, Int, Date?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var taskTitle = ""
    @State private var taskDescription = ""
    @State private var selectedCategory: FamilyTask.TaskCategory = .chores
    @State private var selectedAssignee: UUID?
    @State private var points = 10
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var showingValidationError = false
    @State private var validationMessage = ""
    
    private var sortedUserProfiles: [(UUID, UserProfile)] {
        userProfiles.sorted { $0.value.displayName < $1.value.displayName }
    }
    
    private var isFormValid: Bool {
        !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedAssignee != nil &&
        points > 0
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Task details section
                Section("Task Details") {
                    TextField("Task title", text: $taskTitle)
                        .textInputAutocapitalization(.sentences)
                    
                    TextField("Description (optional)", text: $taskDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(FamilyTask.TaskCategory.allCases, id: \.self) { category in
                            HStack {
                                Text(category.icon)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                }
                
                // Assignment section
                Section("Assignment") {
                    Picker("Assign to", selection: $selectedAssignee) {
                        Text("Select family member")
                            .tag(nil as UUID?)
                        
                        ForEach(sortedUserProfiles, id: \.0) { userId, profile in
                            Text(profile.displayName)
                                .tag(userId as UUID?)
                        }
                    }
                    
                    HStack {
                        Text("Points")
                        
                        Spacer()
                        
                        Stepper(value: $points, in: 1...50, step: 5) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                
                                Text("\(points)")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                
                // Due date section
                Section("Due Date") {
                    Toggle("Set due date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker(
                            "Due date",
                            selection: $dueDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                
                // Preview section
                Section("Preview") {
                    if let assigneeId = selectedAssignee {
                        TaskPreviewCard(
                            title: taskTitle.isEmpty ? "Task title" : taskTitle,
                            description: taskDescription.isEmpty ? nil : taskDescription,
                            category: selectedCategory,
                            assigneeName: userProfiles[assigneeId]?.displayName ?? "Unknown",
                            points: points,
                            dueDate: hasDueDate ? dueDate : nil
                        )
                    } else {
                        Text("Select an assignee to see preview")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createTask()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .alert("Validation Error", isPresented: $showingValidationError) {
            Button("OK") { }
        } message: {
            Text(validationMessage)
        }
    }
    
    // MARK: - Actions
    
    private func createTask() {
        guard isFormValid else {
            validationMessage = "Please fill in all required fields"
            showingValidationError = true
            return
        }
        
        guard let assigneeId = selectedAssignee else {
            validationMessage = "Please select someone to assign this task to"
            showingValidationError = true
            return
        }
        
        let trimmedTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            validationMessage = "Please enter a task title"
            showingValidationError = true
            return
        }
        
        onTaskCreated(
            trimmedTitle,
            selectedCategory,
            assigneeId,
            points,
            hasDueDate ? dueDate : nil
        )
        
        dismiss()
    }
}

// MARK: - Task Preview Card

struct TaskPreviewCard: View {
    let title: String
    let description: String?
    let category: FamilyTask.TaskCategory
    let assigneeName: String
    let points: Int
    let dueDate: Date?
    
    private var dueDateText: String? {
        guard let dueDate = dueDate else { return nil }
        
        let formatter = DateFormatter()
        if Calendar.current.isDate(dueDate, inSameDayAs: Date()) {
            formatter.timeStyle = .short
            return "Due today at \(formatter.string(from: dueDate))"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "Due \(formatter.string(from: dueDate))"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with category and points
            HStack {
                HStack(spacing: 8) {
                    Text(category.icon)
                        .font(.title2)
                    
                    Text(category.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    
                    Text("\(points)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(8)
            }
            
            // Title
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            // Description
            if let description = description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Assignment and due date info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Assigned to \(assigneeName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let dueDateText = dueDateText {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(dueDateText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    let mockProfiles = [
        UUID(): UserProfile(displayName: "Ethan Mawere", appleUserIdHash: "hash_ethan"),
        UUID(): UserProfile(displayName: "Zoe Mawere", appleUserIdHash: "hash_zoe"),
        UUID(): UserProfile(displayName: "Grace Mawere", appleUserIdHash: "hash_grace")
    ]
    
    return AddTaskSheet(
        userProfiles: mockProfiles,
        onTaskCreated: { _, _, _, _, _ in }
    )
}