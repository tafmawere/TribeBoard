import SwiftUI

struct TasksView: View {
    @StateObject private var viewModel: TasksViewModel
    @State private var showingFilterSheet = false
    @State private var showingAddTaskSheet = false
    
    // MARK: - Initialization
    
    init(currentUserId: UUID, currentUserRole: Role) {
        self._viewModel = StateObject(wrappedValue: TasksViewModel(
            currentUserId: currentUserId,
            currentUserRole: currentUserRole
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.allTasks.isEmpty {
                    // Initial loading state
                    LoadingStateView(
                        message: "Loading family tasks...",
                        style: .card
                    )
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Task statistics header
                            taskStatisticsView
                            
                            // Filter and sort controls
                            filterAndSortView
                            
                            // Tasks list
                            tasksListView
                        }
                        .padding()
                    }
                    .refreshable {
                        viewModel.refreshData()
                    }
                }
            }
            .navigationTitle("Family Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Filter") {
                        showingFilterSheet = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Task") {
                        showingAddTaskSheet = true
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadMockData()
        }
        .withToast()
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            TaskFilterSheet(
                selectedFilter: $viewModel.selectedFilter,
                selectedSort: $viewModel.selectedSort
            )
        }
        .sheet(isPresented: $showingAddTaskSheet) {
            AddTaskSheet(
                userProfiles: viewModel.userProfiles,
                onTaskCreated: { title, category, assignedTo, points, dueDate in
                    viewModel.addMockTask(
                        title: title,
                        category: category,
                        assignedTo: assignedTo,
                        points: points,
                        dueDate: dueDate
                    )
                }
            )
        }
        .sheet(isPresented: $viewModel.showingTaskDetail) {
            if let task = viewModel.selectedTask {
                TaskDetailView(
                    task: task,
                    userProfiles: viewModel.userProfiles,
                    canEdit: viewModel.canEditTask(task),
                    canComplete: viewModel.canCompleteTask(task),
                    onStatusChange: { newStatus in
                        switch newStatus {
                        case .pending:
                            viewModel.markTaskPending(task)
                        case .inProgress:
                            viewModel.markTaskInProgress(task)
                        case .completed:
                            viewModel.markTaskCompleted(task)
                        case .overdue:
                            break // Can't manually set to overdue
                        }
                    },
                    onDelete: {
                        viewModel.deleteTask(task)
                        viewModel.showingTaskDetail = false
                    }
                )
            }
        }
    }
    
    // MARK: - View Components
    
    private var taskStatisticsView: some View {
        let stats = viewModel.taskStats
        
        return VStack(spacing: 16) {
            // Header with user points
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Progress")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(stats.totalPoints) points earned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(stats.availablePoints)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.brandPrimary)
                    
                    Text("points available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Statistics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                TaskStatCard(
                    title: "My Tasks",
                    value: "\(stats.myTasks)",
                    icon: "person.circle",
                    color: .blue
                )
                
                TaskStatCard(
                    title: "Pending",
                    value: "\(stats.pendingTasks)",
                    icon: "clock",
                    color: .orange
                )
                
                TaskStatCard(
                    title: "Completed",
                    value: "\(stats.completedTasks)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var filterAndSortView: some View {
        HStack {
            // Current filter display
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.brandPrimary)
                
                Text(viewModel.selectedFilter.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if viewModel.selectedFilter != .all {
                    Button("Clear") {
                        viewModel.setFilter(.all)
                    }
                    .font(.caption)
                    .foregroundColor(.brandPrimary)
                }
            }
            
            Spacer()
            
            // Sort display
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(viewModel.selectedSort.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var tasksListView: some View {
        LazyVStack(spacing: 12) {
            if viewModel.filteredAndSortedTasks.isEmpty {
                // Empty state
                TasksEmptyStateView(
                    filter: viewModel.selectedFilter,
                    onAddTask: {
                        showingAddTaskSheet = true
                    },
                    onClearFilter: {
                        viewModel.setFilter(.all)
                    }
                )
            } else {
                ForEach(viewModel.filteredAndSortedTasks, id: \.id) { task in
                    TaskCard(
                        task: task,
                        userProfiles: viewModel.userProfiles,
                        canEdit: viewModel.canEditTask(task),
                        canComplete: viewModel.canCompleteTask(task),
                        onTap: {
                            viewModel.showTaskDetail(task)
                        },
                        onStatusChange: { newStatus in
                            switch newStatus {
                            case .pending:
                                viewModel.markTaskPending(task)
                            case .inProgress:
                                viewModel.markTaskInProgress(task)
                            case .completed:
                                viewModel.markTaskCompleted(task)
                            case .overdue:
                                break // Can't manually set to overdue
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Task Statistics Card

struct TaskStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Empty State View

struct TasksEmptyStateView: View {
    let filter: TaskFilter
    let onAddTask: () -> Void
    let onClearFilter: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                if filter != .all {
                    Button("Clear Filter") {
                        onClearFilter()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                
                Button("Add First Task") {
                    onAddTask()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var emptyStateTitle: String {
        switch filter {
        case .all:
            return "No Tasks Yet"
        case .myTasks:
            return "No Tasks Assigned to You"
        case .pending:
            return "No Pending Tasks"
        case .inProgress:
            return "No Tasks in Progress"
        case .completed:
            return "No Completed Tasks"
        case .overdue:
            return "No Overdue Tasks"
        case .category(let category):
            return "No \(category.displayName) Tasks"
        }
    }
    
    private var emptyStateMessage: String {
        switch filter {
        case .all:
            return "Get started by creating your first family task!"
        case .myTasks:
            return "You don't have any tasks assigned to you right now."
        case .pending:
            return "All tasks have been started or completed!"
        case .inProgress:
            return "No tasks are currently being worked on."
        case .completed:
            return "No tasks have been completed yet."
        case .overdue:
            return "Great! No tasks are overdue."
        case .category(let category):
            return "No tasks in the \(category.displayName) category yet."
        }
    }
}

// MARK: - Preview

#Preview {
    TasksView(currentUserId: UUID(), currentUserRole: .parentAdmin)
}