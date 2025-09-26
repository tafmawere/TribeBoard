import SwiftUI

/// Sheet view for filtering shopping tasks
struct TaskFilterSheet: View {
    @Binding var selectedFilters: TaskFilters
    let availableFamilyMembers: [String]
    let onFiltersChanged: (TaskFilters) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var tempFilters: TaskFilters
    
    init(
        selectedFilters: Binding<TaskFilters>,
        availableFamilyMembers: [String],
        onFiltersChanged: @escaping (TaskFilters) -> Void
    ) {
        self._selectedFilters = selectedFilters
        self.availableFamilyMembers = availableFamilyMembers
        self.onFiltersChanged = onFiltersChanged
        self._tempFilters = State(initialValue: selectedFilters.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Family member filter
                Section("Assigned To") {
                    Picker("Family Member", selection: $tempFilters.assignedTo) {
                        Text("All Members")
                            .tag(String?.none)
                        
                        ForEach(availableFamilyMembers, id: \.self) { member in
                            Text(member)
                                .tag(String?.some(member))
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Status filter
                Section("Task Status") {
                    Picker("Status", selection: $tempFilters.status) {
                        Text("All Statuses")
                            .tag(TaskStatus?.none)
                        
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            HStack {
                                Text(status.emoji)
                                Text(status.rawValue)
                            }
                            .tag(TaskStatus?.some(status))
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Special filters
                Section("Special Filters") {
                    Toggle("Show Overdue Only", isOn: $tempFilters.showOverdueOnly)
                }
                
                // Quick filter presets
                Section("Quick Filters") {
                    Button("My Tasks") {
                        tempFilters.assignedTo = "Current User" // In real app, use actual current user
                        tempFilters.status = nil
                        tempFilters.showOverdueOnly = false
                    }
                    
                    Button("Pending Tasks") {
                        tempFilters.assignedTo = nil
                        tempFilters.status = .pending
                        tempFilters.showOverdueOnly = false
                    }
                    
                    Button("Overdue Tasks") {
                        tempFilters.assignedTo = nil
                        tempFilters.status = nil
                        tempFilters.showOverdueOnly = true
                    }
                }
                
                // Clear filters
                Section {
                    Button("Clear All Filters") {
                        tempFilters = TaskFilters()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filter Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        selectedFilters = tempFilters
                        onFiltersChanged(tempFilters)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview("Task Filter Sheet") {
    TaskFilterSheet(
        selectedFilters: .constant(TaskFilters()),
        availableFamilyMembers: ["Tafadzwa Mawere", "Grace Mawere", "Ethan Mawere", "Zoe Mawere"],
        onFiltersChanged: { _ in }
    )
}