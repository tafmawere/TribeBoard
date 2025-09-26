import SwiftUI
import Foundation

/// ViewModel for managing grocery list state and operations
@MainActor
class GroceryListViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// All grocery items (both weekly and urgent)
    @Published var groceryItems: [GroceryItem] = []
    
    /// Currently selected tab
    @Published var selectedTab: GroceryListTab = .weekly
    
    /// Loading state for async operations
    @Published var isLoading = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Success message for operations
    @Published var successMessage: String?
    
    /// New urgent item being added
    @Published var newUrgentItem: NewUrgentItem = NewUrgentItem()
    
    /// Show add urgent item sheet
    @Published var showAddUrgentItemSheet = false
    
    /// Selected grocery platform for ordering
    @Published var selectedPlatform: GroceryPlatform?
    
    /// Show platform selection sheet
    @Published var showPlatformSelection = false
    
    /// Available grocery platforms
    @Published var availablePlatforms: [GroceryPlatform] = []
    
    // MARK: - Computed Properties
    
    /// Weekly grocery items (from meal planning)
    var weeklyGroceryItems: [GroceryItem] {
        groceryItems.filter { !$0.isUrgent }.sorted { item1, item2 in
            // Sort by priority first, then by name
            if item1.priority.sortOrder != item2.priority.sortOrder {
                return item1.priority.sortOrder < item2.priority.sortOrder
            }
            return item1.ingredient.name < item2.ingredient.name
        }
    }
    
    /// Urgent grocery items (manually added)
    var urgentGroceryItems: [GroceryItem] {
        groceryItems.filter { $0.isUrgent }.sorted { item1, item2 in
            // Sort by added date (newest first)
            return item1.addedDate > item2.addedDate
        }
    }
    
    /// Items for the currently selected tab
    var itemsForSelectedTab: [GroceryItem] {
        switch selectedTab {
        case .weekly:
            return weeklyGroceryItems
        case .urgent:
            return urgentGroceryItems
        }
    }
    
    /// Total item count for badge display
    var totalItemCount: Int {
        groceryItems.count
    }
    
    /// Urgent item count for badge display
    var urgentItemCount: Int {
        urgentGroceryItems.count
    }
    
    /// Weekly item count for badge display
    var weeklyItemCount: Int {
        weeklyGroceryItems.count
    }
    
    /// Whether there are items to order
    var hasItemsToOrder: Bool {
        !itemsForSelectedTab.isEmpty
    }
    
    /// Estimated total cost (mock calculation)
    var estimatedTotalCost: Double {
        // Mock price calculation based on item count
        let basePrice = 15.0 // Base price per item
        let urgentMultiplier = 1.2 // Urgent items cost more
        
        let weeklyTotal = Double(weeklyItemCount) * basePrice
        let urgentTotal = Double(urgentItemCount) * basePrice * urgentMultiplier
        
        return weeklyTotal + urgentTotal
    }
    
    /// Formatted estimated cost
    var formattedEstimatedCost: String {
        return String(format: "R%.0f", estimatedTotalCost)
    }
    
    // MARK: - Initialization
    
    init() {
        setupInitialState()
    }
    
    // MARK: - Public Methods
    
    /// Load grocery items from data provider
    func loadGroceryItems() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // Load mock grocery items
            let items = MealPlanDataProvider.mockGroceryItems()
            
            await MainActor.run {
                self.groceryItems = items
                self.successMessage = "Grocery list updated"
                
                // Auto-clear success message
                Task {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.successMessage = nil
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load grocery items: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    /// Generate grocery list from pantry check results
    func generateGroceryList(from missingIngredients: [Ingredient], linkedMeals: [String: String] = [:]) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Simulate processing time
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            let newItems = missingIngredients.map { ingredient in
                GroceryItem(
                    ingredient: ingredient,
                    linkedMeal: linkedMeals[ingredient.name],
                    addedBy: "System",
                    addedDate: Date(),
                    isUrgent: false,
                    notes: "From meal plan"
                )
            }
            
            await MainActor.run {
                // Remove existing system-generated items to avoid duplicates
                self.groceryItems.removeAll { $0.addedBy == "System" && !$0.isUrgent }
                
                // Add new items
                self.groceryItems.append(contentsOf: newItems)
                
                self.successMessage = "Grocery list generated from pantry check"
                self.selectedTab = .weekly // Switch to weekly tab to show new items
                
                // Auto-clear success message
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        self.successMessage = nil
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to generate grocery list: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    /// Add urgent item to the list
    func addUrgentItem() {
        guard !newUrgentItem.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Item name is required"
            return
        }
        
        let ingredient = Ingredient(
            name: newUrgentItem.name,
            quantity: newUrgentItem.quantity,
            unit: newUrgentItem.unit,
            emoji: newUrgentItem.emoji,
            category: newUrgentItem.category
        )
        
        let groceryItem = GroceryItem(
            ingredient: ingredient,
            linkedMeal: nil,
            addedBy: newUrgentItem.addedBy,
            addedDate: Date(),
            isUrgent: true,
            notes: newUrgentItem.notes.isEmpty ? nil : newUrgentItem.notes
        )
        
        groceryItems.append(groceryItem)
        
        // Reset form and close sheet
        newUrgentItem = NewUrgentItem()
        showAddUrgentItemSheet = false
        
        // Switch to urgent tab to show new item
        selectedTab = .urgent
        
        successMessage = "Urgent item added to list"
        
        // Auto-clear success message
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                self.successMessage = nil
            }
        }
    }
    
    /// Remove item from grocery list
    func removeItem(_ item: GroceryItem) {
        groceryItems.removeAll { $0.id == item.id }
        successMessage = "Item removed from list"
        
        // Auto-clear success message
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                self.successMessage = nil
            }
        }
    }
    
    /// Toggle item completion status
    func toggleItemCompletion(_ item: GroceryItem) {
        if let index = groceryItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = groceryItems[index]
            updatedItem = GroceryItem(
                ingredient: updatedItem.ingredient,
                linkedMeal: updatedItem.linkedMeal,
                addedBy: updatedItem.addedBy,
                addedDate: updatedItem.addedDate,
                isUrgent: updatedItem.isUrgent,
                isCompleted: !updatedItem.isCompleted,
                notes: updatedItem.notes
            )
            groceryItems[index] = updatedItem
        }
    }
    
    /// Switch to a different tab
    func switchTab(to tab: GroceryListTab) {
        selectedTab = tab
    }
    
    /// Load available grocery platforms
    func loadGroceryPlatforms() {
        availablePlatforms = MealPlanDataProvider.mockGroceryPlatforms()
    }
    
    /// Select a grocery platform for ordering
    func selectPlatform(_ platform: GroceryPlatform) {
        selectedPlatform = platform
        showPlatformSelection = false
        
        // The OrderPlatformSelectionView handles the submission and feedback
        // Just update our local state
        successMessage = "Order submitted to \(platform.name)!"
        
        // Auto-clear success message
        Task {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                self.successMessage = nil
            }
        }
    }
    
    /// Show platform selection sheet
    func showPlatformSelectionSheet() {
        loadGroceryPlatforms()
        showPlatformSelection = true
    }
    
    /// Show add urgent item sheet
    func showAddUrgentItemForm() {
        newUrgentItem = NewUrgentItem()
        showAddUrgentItemSheet = true
    }
    
    /// Filter items by category
    func filterItems(by category: IngredientCategory) -> [GroceryItem] {
        return itemsForSelectedTab.filter { $0.ingredient.category == category }
    }
    
    /// Get items grouped by category
    func itemsGroupedByCategory() -> [IngredientCategory: [GroceryItem]] {
        return Dictionary(grouping: itemsForSelectedTab) { $0.ingredient.category }
    }
    
    /// Clear all completed items
    func clearCompletedItems() {
        let completedCount = groceryItems.filter { $0.isCompleted }.count
        groceryItems.removeAll { $0.isCompleted }
        
        if completedCount > 0 {
            successMessage = "Cleared \(completedCount) completed item\(completedCount == 1 ? "" : "s")"
            
            // Auto-clear success message
            Task {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    self.successMessage = nil
                }
            }
        }
    }
    
    /// Clear error message
    func clearErrorMessage() {
        errorMessage = nil
    }
    
    /// Clear success message
    func clearSuccessMessage() {
        successMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        // Load initial data
        Task {
            await loadGroceryItems()
        }
    }
}

// MARK: - Supporting Models

/// Enum for grocery list tabs
enum GroceryListTab: String, CaseIterable {
    case weekly = "Weekly List"
    case urgent = "Urgent Items"
    
    var icon: String {
        switch self {
        case .weekly: return "calendar.badge.clock"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .weekly: return "blue"
        case .urgent: return "red"
        }
    }
}

/// Model for creating new urgent items
struct NewUrgentItem {
    var name: String = ""
    var quantity: String = "1"
    var unit: String = ""
    var emoji: String = "🛒"
    var category: IngredientCategory = .pantry
    var notes: String = ""
    var addedBy: String = "Current User" // In real app, this would be the current user's name
    
    /// Whether the form is valid for submission
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}