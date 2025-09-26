import SwiftUI
import Foundation

// MARK: - AppState HomeLife Extension

extension AppState {
    
    // MARK: - HomeLife Navigation Methods
    
    /// Navigate to a specific HomeLife tab
    func navigateToHomeLifeTab(_ tab: HomeLifeTab) {
        selectedHomeLifeTab = tab
        
        // Handle specific navigation logic for each tab
        switch tab {
        case .mealPlan:
            // Navigation to MealPlanDashboardView will be handled by HomeLifeNavigationView
            break
        case .groceryList:
            // Navigation to GroceryListView will be handled by HomeLifeNavigationView
            break
        case .tasks:
            // Navigation to TaskListView will be handled by HomeLifeNavigationView
            break
        case .pantry:
            // Navigation to PantryCheckView will be handled by HomeLifeNavigationView
            break
        }
    }
    
    /// Reset HomeLife navigation to root
    func resetHomeLifeNavigation() {
        homeLifeNavigationPath = NavigationPath()
        selectedHomeLifeTab = .mealPlan
    }
    
    /// Navigate back in HomeLife navigation stack
    func navigateBackInHomeLife() {
        if !homeLifeNavigationPath.isEmpty {
            homeLifeNavigationPath.removeLast()
        }
    }
    
    // MARK: - HomeLife Data Management
    
    /// Load meal plan data for HomeLife
    func loadHomeLifeMealPlan() async {
        await MainActor.run {
            homeLifeIsLoading = true
            homeLifeErrorMessage = nil
        }
        
        do {
            // Simulate loading delay for realistic UX
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Load mock meal plan data
            let mealPlan = MealPlanDataProvider.mockMealPlan()
            
            await MainActor.run {
                self.currentMealPlan = mealPlan
                self.homeLifeIsLoading = false
                self.homeLifeSuccessMessage = "Meal plan loaded successfully"
            }
        } catch {
            await MainActor.run {
                self.homeLifeIsLoading = false
                self.showHomeLifeError(.mealPlanLoadFailed)
            }
        }
    }
    
    /// Generate grocery list from pantry check
    func generateGroceryList(from ingredients: [Ingredient]) async {
        await MainActor.run {
            homeLifeIsLoading = true
            homeLifeErrorMessage = nil
        }
        
        do {
            // Simulate processing delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Generate grocery items from unchecked ingredients
            let uncheckedIngredients = ingredients.filter { !$0.isAvailableInPantry }
            let newGroceryItems = uncheckedIngredients.map { ingredient in
                GroceryItem(
                    ingredient: ingredient,
                    linkedMeal: "Weekly Meal Plan",
                    addedBy: currentUser?.displayName ?? "System",
                    addedDate: Date(),
                    isUrgent: false,
                    notes: nil
                )
            }
            
            await MainActor.run {
                self.groceryList.append(contentsOf: newGroceryItems)
                self.homeLifeIsLoading = false
                self.homeLifeSuccessMessage = "Grocery list generated with \(newGroceryItems.count) items"
            }
        } catch {
            await MainActor.run {
                self.homeLifeIsLoading = false
                self.showHomeLifeError(.groceryListGenerationFailed)
            }
        }
    }
    
    /// Add urgent grocery item
    func addUrgentGroceryItem(_ item: GroceryItem) {
        groceryList.append(item)
        homeLifeSuccessMessage = "Urgent item added to grocery list"
    }
    
    /// Remove grocery item
    func removeGroceryItem(_ item: GroceryItem) {
        groceryList.removeAll { $0.id == item.id }
        homeLifeSuccessMessage = "Item removed from grocery list"
    }
    
    /// Create shopping task from grocery items
    func createShoppingTask(
        items: [GroceryItem],
        assignedTo: String,
        taskType: TaskType,
        dueDate: Date,
        notes: String?,
        location: TaskLocation?
    ) async {
        await MainActor.run {
            homeLifeIsLoading = true
            homeLifeErrorMessage = nil
        }
        
        do {
            // Simulate task creation delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            let newTask = ShoppingTask(
                items: items,
                assignedTo: assignedTo,
                taskType: taskType,
                dueDate: dueDate,
                notes: notes,
                location: location,
                status: .pending,
                createdBy: currentUser?.displayName ?? "System"
            )
            
            await MainActor.run {
                self.shoppingTasks.append(newTask)
                
                // Remove items from grocery list if they were converted to task
                for item in items {
                    self.groceryList.removeAll { $0.id == item.id }
                }
                
                self.homeLifeIsLoading = false
                self.homeLifeSuccessMessage = "Shopping task created and assigned to \(assignedTo)"
            }
        } catch {
            await MainActor.run {
                self.homeLifeIsLoading = false
                self.showHomeLifeError(.taskCreationFailed)
            }
        }
    }
    
    /// Update shopping task status
    func updateShoppingTaskStatus(_ task: ShoppingTask, status: TaskStatus) {
        if let index = shoppingTasks.firstIndex(where: { $0.id == task.id }) {
            shoppingTasks[index].status = status
            homeLifeSuccessMessage = "Task status updated to \(status.rawValue)"
        }
    }
    
    /// Load shopping tasks
    func loadShoppingTasks() async {
        await MainActor.run {
            homeLifeIsLoading = true
            homeLifeErrorMessage = nil
        }
        
        do {
            // Simulate loading delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Load mock shopping tasks
            let tasks = MealPlanDataProvider.mockShoppingTasks()
            
            await MainActor.run {
                self.shoppingTasks = tasks
                self.homeLifeIsLoading = false
            }
        } catch {
            await MainActor.run {
                self.homeLifeIsLoading = false
                self.showHomeLifeError(.taskCreationFailed)
            }
        }
    }
    
    /// Load comprehensive HomeLife demo data for demo scenarios
    func loadHomeLifeDemoData() async {
        await MainActor.run {
            homeLifeIsLoading = true
            homeLifeErrorMessage = nil
        }
        
        do {
            // Simulate loading delay for realistic demo experience
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Load comprehensive demo data using HomeLifePreviewProvider
            let mealPlan = HomeLifePreviewProvider.weeklyMealPlan()
            let groceryItems = HomeLifePreviewProvider.mixedGroceryList()
            let tasks = HomeLifePreviewProvider.diverseShoppingTasks()
            
            await MainActor.run {
                self.currentMealPlan = mealPlan
                self.groceryList = groceryItems
                self.shoppingTasks = tasks
                self.homeLifeIsLoading = false
                self.homeLifeSuccessMessage = "HomeLife demo data loaded successfully"
            }
        } catch {
            await MainActor.run {
                self.homeLifeIsLoading = false
                self.showHomeLifeError(.mealPlanLoadFailed)
            }
        }
    }
    
    // MARK: - HomeLife Error Handling
    
    /// Show HomeLife-specific error
    func showHomeLifeError(_ error: HomeLifeError) {
        homeLifeErrorMessage = error.localizedDescription
    }
    
    /// Clear HomeLife error message
    func clearHomeLifeError() {
        homeLifeErrorMessage = nil
    }
    
    /// Clear HomeLife success message
    func clearHomeLifeSuccess() {
        homeLifeSuccessMessage = nil
    }
    
    /// Clear all HomeLife messages
    func clearHomeLifeMessages() {
        homeLifeErrorMessage = nil
        homeLifeSuccessMessage = nil
    }
    
    // MARK: - HomeLife State Management
    
    /// Reset HomeLife data to initial state
    func resetHomeLifeData() {
        currentMealPlan = nil
        groceryList = []
        shoppingTasks = []
        homeLifeIsLoading = false
        clearHomeLifeMessages()
        resetHomeLifeNavigation()
    }
    
    /// Get HomeLife data summary for dashboard
    func getHomeLifeSummary() -> HomeLifeSummary {
        return HomeLifeSummary(
            mealPlanCount: currentMealPlan?.meals.count ?? 0,
            groceryItemCount: groceryList.count,
            urgentItemCount: groceryList.filter { $0.isUrgent }.count,
            pendingTaskCount: shoppingTasks.filter { $0.status == .pending }.count,
            overdueTaskCount: shoppingTasks.filter { $0.isOverdue }.count
        )
    }
    
    /// Validate HomeLife data integrity
    func validateHomeLifeData() -> Bool {
        // Validate meal plan
        if let mealPlan = currentMealPlan {
            guard !mealPlan.meals.isEmpty else {
                showHomeLifeError(.dataValidationError("Meal plan cannot be empty"))
                return false
            }
        }
        
        // Validate grocery items
        for item in groceryList {
            guard !item.ingredient.name.isEmpty else {
                showHomeLifeError(.dataValidationError("Grocery item name cannot be empty"))
                return false
            }
        }
        
        // Validate shopping tasks
        for task in shoppingTasks {
            guard !task.items.isEmpty else {
                showHomeLifeError(.dataValidationError("Shopping task must have at least one item"))
                return false
            }
            
            guard !task.assignedTo.isEmpty else {
                showHomeLifeError(.dataValidationError("Shopping task must be assigned to someone"))
                return false
            }
        }
        
        return true
    }
}

// MARK: - HomeLife Summary Data Model

/// Data model for HomeLife dashboard summary
struct HomeLifeSummary {
    let mealPlanCount: Int
    let groceryItemCount: Int
    let urgentItemCount: Int
    let pendingTaskCount: Int
    let overdueTaskCount: Int
    
    /// Computed property that indicates if there are any urgent items
    var hasUrgentItems: Bool {
        urgentItemCount > 0 || overdueTaskCount > 0
    }
    
    /// Computed property that returns a status message
    var statusMessage: String {
        if overdueTaskCount > 0 {
            return "\(overdueTaskCount) overdue task\(overdueTaskCount == 1 ? "" : "s")"
        } else if urgentItemCount > 0 {
            return "\(urgentItemCount) urgent item\(urgentItemCount == 1 ? "" : "s")"
        } else if pendingTaskCount > 0 {
            return "\(pendingTaskCount) pending task\(pendingTaskCount == 1 ? "" : "s")"
        } else {
            return "All caught up!"
        }
    }
}