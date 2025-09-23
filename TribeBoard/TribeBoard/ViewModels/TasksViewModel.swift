import SwiftUI
import Foundation

@MainActor
class TasksViewModel: ObservableObject {
    @Published var allTasks: [FamilyTask] = []
    @Published var userProfiles: [UUID: UserProfile] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var selectedFilter: TaskFilter = .all
    @Published var selectedSort: TaskSort = .dueDate
    @Published var showingTaskDetail = false
    @Published var selectedTask: FamilyTask?
    
    // Current user context
    private let currentUserId: UUID
    private let currentUserRole: Role
    
    // MARK: - Initialization
    
    init(currentUserId: UUID, currentUserRole: Role) {
        self.currentUserId = currentUserId
        self.currentUserRole = currentUserRole
    }
    
    // MARK: - Computed Properties
    
    var filteredAndSortedTasks: [FamilyTask] {
        let filtered = filteredTasks
        return sortTasks(filtered)
    }
    
    private var filteredTasks: [FamilyTask] {
        switch selectedFilter {
        case .all:
            return allTasks
        case .myTasks:
            return allTasks.filter { $0.assignedTo == currentUserId }
        case .pending:
            return allTasks.filter { $0.status == .pending }
        case .inProgress:
            return allTasks.filter { $0.status == .inProgress }
        case .completed:
            return allTasks.filter { $0.status == .completed }
        case .overdue:
            return allTasks.filter { $0.status == .overdue }
        case .category(let category):
            return allTasks.filter { $0.category == category }
        }
    }
    
    private func sortTasks(_ tasks: [FamilyTask]) -> [FamilyTask] {
        switch selectedSort {
        case .dueDate:
            return tasks.sorted { task1, task2 in
                // Tasks without due dates go to the end
                guard let date1 = task1.dueDate else { return false }
                guard let date2 = task2.dueDate else { return true }
                return date1 < date2
            }
        case .priority:
            return tasks.sorted { $0.points > $1.points }
        case .assignee:
            return tasks.sorted { task1, task2 in
                let name1 = userProfiles[task1.assignedTo]?.displayName ?? ""
                let name2 = userProfiles[task2.assignedTo]?.displayName ?? ""
                return name1 < name2
            }
        case .category:
            return tasks.sorted { $0.category.displayName < $1.category.displayName }
        case .status:
            return tasks.sorted { $0.status.displayName < $1.status.displayName }
        }
    }
    
    // MARK: - Statistics
    
    var taskStats: TaskStatistics {
        let myTasks = allTasks.filter { $0.assignedTo == currentUserId }
        
        return TaskStatistics(
            totalTasks: allTasks.count,
            myTasks: myTasks.count,
            pendingTasks: allTasks.filter { $0.status == .pending }.count,
            inProgressTasks: allTasks.filter { $0.status == .inProgress }.count,
            completedTasks: allTasks.filter { $0.status == .completed }.count,
            overdueTasks: allTasks.filter { $0.status == .overdue }.count,
            totalPoints: myTasks.filter { $0.status == .completed }.reduce(0) { $0 + $1.points },
            availablePoints: myTasks.filter { $0.status != .completed }.reduce(0) { $0 + $1.points }
        )
    }
    
    // MARK: - Data Loading
    
    func loadMockData() {
        isLoading = true
        
        // Simulate loading delay for realistic experience
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadTasks()
            self.loadUserProfiles()
            self.updateOverdueTasks()
            self.isLoading = false
        }
    }
    
    private func loadTasks() {
        allTasks = MockDataGenerator.mockFamilyTasks()
    }
    
    private func loadUserProfiles() {
        let (_, users, _) = MockDataGenerator.mockMawereFamily()
        userProfiles = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }
    
    private func updateOverdueTasks() {
        let now = Date()
        for index in allTasks.indices {
            if let dueDate = allTasks[index].dueDate,
               dueDate < now && allTasks[index].status != .completed {
                allTasks[index] = FamilyTask(
                    id: allTasks[index].id,
                    title: allTasks[index].title,
                    description: allTasks[index].description,
                    assignedTo: allTasks[index].assignedTo,
                    assignedBy: allTasks[index].assignedBy,
                    dueDate: allTasks[index].dueDate,
                    status: .overdue,
                    points: allTasks[index].points,
                    category: allTasks[index].category,
                    createdAt: allTasks[index].createdAt
                )
            }
        }
    }
    
    // MARK: - Task Actions
    
    func markTaskCompleted(_ task: FamilyTask) {
        guard let index = allTasks.firstIndex(where: { $0.id == task.id }) else { return }
        
        allTasks[index] = FamilyTask(
            id: task.id,
            title: task.title,
            description: task.description,
            assignedTo: task.assignedTo,
            assignedBy: task.assignedBy,
            dueDate: task.dueDate,
            status: .completed,
            points: task.points,
            category: task.category,
            createdAt: task.createdAt
        )
        
        let assigneeName = userProfiles[task.assignedTo]?.displayName ?? "Someone"
        successMessage = "\(assigneeName) completed '\(task.title)' and earned \(task.points) points! 🎉"
        
        clearMessageAfterDelay()
    }
    
    func markTaskInProgress(_ task: FamilyTask) {
        guard let index = allTasks.firstIndex(where: { $0.id == task.id }) else { return }
        
        allTasks[index] = FamilyTask(
            id: task.id,
            title: task.title,
            description: task.description,
            assignedTo: task.assignedTo,
            assignedBy: task.assignedBy,
            dueDate: task.dueDate,
            status: .inProgress,
            points: task.points,
            category: task.category,
            createdAt: task.createdAt
        )
        
        successMessage = "Task '\(task.title)' marked as in progress"
        clearMessageAfterDelay()
    }
    
    func markTaskPending(_ task: FamilyTask) {
        guard let index = allTasks.firstIndex(where: { $0.id == task.id }) else { return }
        
        allTasks[index] = FamilyTask(
            id: task.id,
            title: task.title,
            description: task.description,
            assignedTo: task.assignedTo,
            assignedBy: task.assignedBy,
            dueDate: task.dueDate,
            status: .pending,
            points: task.points,
            category: task.category,
            createdAt: task.createdAt
        )
        
        successMessage = "Task '\(task.title)' marked as pending"
        clearMessageAfterDelay()
    }
    
    func deleteTask(_ task: FamilyTask) {
        allTasks.removeAll { $0.id == task.id }
        successMessage = "Task '\(task.title)' deleted"
        clearMessageAfterDelay()
    }
    
    func showTaskDetail(_ task: FamilyTask) {
        selectedTask = task
        showingTaskDetail = true
    }
    
    // MARK: - Filtering and Sorting
    
    func setFilter(_ filter: TaskFilter) {
        selectedFilter = filter
    }
    
    func setSort(_ sort: TaskSort) {
        selectedSort = sort
    }
    
    // MARK: - Mock Task Creation
    
    func addMockTask(title: String, category: FamilyTask.TaskCategory, assignedTo: UUID, points: Int, dueDate: Date?) {
        let newTask = FamilyTask(
            id: UUID(),
            title: title,
            description: "Mock task created for demonstration",
            assignedTo: assignedTo,
            assignedBy: currentUserId,
            dueDate: dueDate,
            status: .pending,
            points: points,
            category: category,
            createdAt: Date()
        )
        
        allTasks.append(newTask)
        successMessage = "Task '\(title)' created successfully!"
        clearMessageAfterDelay()
    }
    
    // MARK: - Helper Methods
    
    func userName(for userId: UUID) -> String {
        return userProfiles[userId]?.displayName ?? "Unknown User"
    }
    
    func canEditTask(_ task: FamilyTask) -> Bool {
        // Parent admins and adults can edit any task
        // Users can edit their own tasks
        return currentUserRole == .parentAdmin || 
               currentUserRole == .adult || 
               task.assignedTo == currentUserId
    }
    
    func canCompleteTask(_ task: FamilyTask) -> Bool {
        // Only the assigned user can complete their task
        return task.assignedTo == currentUserId && task.status != .completed
    }
    
    func refreshData() {
        loadMockData()
    }
    
    private func clearMessageAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.successMessage = nil
            self.errorMessage = nil
        }
    }
    
    // MARK: - Mock Error Scenarios
    
    func simulateNetworkError() {
        errorMessage = "Unable to load tasks. Please check your connection and try again."
        clearMessageAfterDelay()
    }
    
    func simulateTaskCreationError() {
        errorMessage = "Failed to create task. Please try again."
        clearMessageAfterDelay()
    }
}

// MARK: - Supporting Types

enum TaskFilter: CaseIterable, Equatable {
    case all
    case myTasks
    case pending
    case inProgress
    case completed
    case overdue
    case category(FamilyTask.TaskCategory)
    
    var displayName: String {
        switch self {
        case .all: return "All Tasks"
        case .myTasks: return "My Tasks"
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .overdue: return "Overdue"
        case .category(let category): return category.displayName
        }
    }
    
    static var allCases: [TaskFilter] {
        return [.all, .myTasks, .pending, .inProgress, .completed, .overdue] +
               FamilyTask.TaskCategory.allCases.map { .category($0) }
    }
}

enum TaskSort: CaseIterable {
    case dueDate
    case priority
    case assignee
    case category
    case status
    
    var displayName: String {
        switch self {
        case .dueDate: return "Due Date"
        case .priority: return "Priority (Points)"
        case .assignee: return "Assignee"
        case .category: return "Category"
        case .status: return "Status"
        }
    }
}

struct TaskStatistics {
    let totalTasks: Int
    let myTasks: Int
    let pendingTasks: Int
    let inProgressTasks: Int
    let completedTasks: Int
    let overdueTasks: Int
    let totalPoints: Int
    let availablePoints: Int
}

// MARK: - Preview Helper

#if DEBUG
extension TasksViewModel {
    static let preview: TasksViewModel = {
        let viewModel = TasksViewModel(currentUserId: UUID(), currentUserRole: .parentAdmin)
        viewModel.loadMockData()
        return viewModel
    }()
}
#endif