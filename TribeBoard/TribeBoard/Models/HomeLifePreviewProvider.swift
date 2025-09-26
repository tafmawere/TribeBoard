import SwiftUI
import Foundation

/// Comprehensive preview data provider for HomeLife features
/// Provides realistic family scenarios for SwiftUI previews and testing
struct HomeLifePreviewProvider {
    
    // MARK: - Family Scenarios
    
    /// Small family with 2 adults and 1 child
    static func smallFamily() -> (family: Family, users: [UserProfile], memberships: [Membership]) {
        let family = Family(
            name: "The Johnsons",
            code: "JOHN123",
            createdByUserId: UUID()
        )
        
        let users = [
            UserProfile(
                displayName: "Sarah Johnson",
                appleUserIdHash: "sarah_hash_12345"
            ),
            UserProfile(
                displayName: "Mike Johnson",
                appleUserIdHash: "mike_hash_67890"
            ),
            UserProfile(
                displayName: "Emma Johnson",
                appleUserIdHash: "emma_hash_54321"
            )
        ]
        
        let memberships = [
            Membership(
                family: family,
                user: users[0],
                role: .parentAdmin
            ),
            Membership(
                family: family,
                user: users[1],
                role: .adult
            ),
            Membership(
                family: family,
                user: users[2],
                role: .kid
            )
        ]
        
        return (family, users, memberships)
    }
    
    /// Large family with multiple children
    static func largeFamily() -> (family: Family, users: [UserProfile], memberships: [Membership]) {
        let family = Family(
            name: "The Williams Family",
            code: "WILL456",
            createdByUserId: UUID()
        )
        
        let users = [
            UserProfile(displayName: "David Williams", appleUserIdHash: "david_hash_12345"),
            UserProfile(displayName: "Lisa Williams", appleUserIdHash: "lisa_hash_67890"),
            UserProfile(displayName: "Alex Williams", appleUserIdHash: "alex_hash_54321"),
            UserProfile(displayName: "Sophie Williams", appleUserIdHash: "sophie_hash_98765"),
            UserProfile(displayName: "Jake Williams", appleUserIdHash: "jake_hash_13579")
        ]
        
        let memberships = [
            Membership(family: family, user: users[0], role: .parentAdmin),
            Membership(family: family, user: users[1], role: .parentAdmin),
            Membership(family: family, user: users[2], role: .kid),
            Membership(family: family, user: users[3], role: .kid),
            Membership(family: family, user: users[4], role: .kid)
        ]
        
        return (family, users, memberships)
    }
    
    // MARK: - Meal Plan Scenarios
    
    /// Weekly meal plan with diverse meals
    static func weeklyMealPlan() -> MealPlan {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        let meals = [
            // Monday
            PlannedMeal(
                name: "Spaghetti Bolognese",
                date: startOfWeek,
                ingredients: [
                    Ingredient(name: "Spaghetti pasta", quantity: "1", unit: "box", emoji: "🍝", category: .pantry),
                    Ingredient(name: "Ground beef", quantity: "1", unit: "lb", emoji: "🥩", category: .meat),
                    Ingredient(name: "Tomatoes", quantity: "4", unit: "medium", emoji: "🍅", category: .produce),
                    Ingredient(name: "Onion", quantity: "1", unit: "large", emoji: "🧅", category: .produce),
                    Ingredient(name: "Garlic", quantity: "3", unit: "cloves", emoji: "🧄", category: .produce)
                ],
                servings: 4,
                mealType: .dinner,
                estimatedPrepTime: 45
            ),
            
            // Tuesday
            PlannedMeal(
                name: "Chicken Stir Fry",
                date: Calendar.current.date(byAdding: .day, value: 1, to: startOfWeek) ?? startOfWeek,
                ingredients: [
                    Ingredient(name: "Chicken breast", quantity: "1", unit: "lb", emoji: "🐔", category: .meat),
                    Ingredient(name: "Broccoli", quantity: "2", unit: "cups", emoji: "🥦", category: .produce),
                    Ingredient(name: "Bell peppers", quantity: "2", unit: "medium", emoji: "🫑", category: .produce),
                    Ingredient(name: "Soy sauce", quantity: "3", unit: "tbsp", emoji: "🥢", category: .pantry),
                    Ingredient(name: "Rice", quantity: "2", unit: "cups", emoji: "🍚", category: .pantry)
                ],
                servings: 4,
                mealType: .dinner,
                estimatedPrepTime: 30
            ),
            
            // Wednesday
            PlannedMeal(
                name: "Fish Tacos",
                date: Calendar.current.date(byAdding: .day, value: 2, to: startOfWeek) ?? startOfWeek,
                ingredients: [
                    Ingredient(name: "White fish fillets", quantity: "1", unit: "lb", emoji: "🐟", category: .meat),
                    Ingredient(name: "Corn tortillas", quantity: "8", unit: "pieces", emoji: "🌮", category: .pantry),
                    Ingredient(name: "Cabbage", quantity: "1/2", unit: "head", emoji: "🥬", category: .produce),
                    Ingredient(name: "Lime", quantity: "2", unit: "medium", emoji: "🍋", category: .produce),
                    Ingredient(name: "Avocado", quantity: "2", unit: "medium", emoji: "🥑", category: .produce)
                ],
                servings: 4,
                mealType: .dinner,
                estimatedPrepTime: 25
            ),
            
            // Thursday
            PlannedMeal(
                name: "Vegetable Curry",
                date: Calendar.current.date(byAdding: .day, value: 3, to: startOfWeek) ?? startOfWeek,
                ingredients: [
                    Ingredient(name: "Chickpeas", quantity: "2", unit: "cans", emoji: "🫘", category: .pantry),
                    Ingredient(name: "Coconut milk", quantity: "1", unit: "can", emoji: "🥥", category: .pantry),
                    Ingredient(name: "Sweet potato", quantity: "2", unit: "large", emoji: "🍠", category: .produce),
                    Ingredient(name: "Spinach", quantity: "4", unit: "cups", emoji: "🥬", category: .produce),
                    Ingredient(name: "Curry powder", quantity: "2", unit: "tbsp", emoji: "🌶️", category: .pantry)
                ],
                servings: 4,
                mealType: .dinner,
                estimatedPrepTime: 40
            ),
            
            // Friday
            PlannedMeal(
                name: "Homemade Pizza",
                date: Calendar.current.date(byAdding: .day, value: 4, to: startOfWeek) ?? startOfWeek,
                ingredients: [
                    Ingredient(name: "Pizza dough", quantity: "2", unit: "balls", emoji: "🍕", category: .pantry),
                    Ingredient(name: "Mozzarella cheese", quantity: "2", unit: "cups", emoji: "🧀", category: .dairy),
                    Ingredient(name: "Tomato sauce", quantity: "1", unit: "jar", emoji: "🍅", category: .pantry),
                    Ingredient(name: "Pepperoni", quantity: "1", unit: "package", emoji: "🍖", category: .meat),
                    Ingredient(name: "Mushrooms", quantity: "1", unit: "cup", emoji: "🍄", category: .produce)
                ],
                servings: 4,
                mealType: .dinner,
                estimatedPrepTime: 35
            )
        ]
        
        return MealPlan(month: Date(), meals: meals)
    }
    
    /// Empty meal plan for testing empty states
    static func emptyMealPlan() -> MealPlan {
        return MealPlan(month: Date(), meals: [])
    }
    
    // MARK: - Grocery List Scenarios
    
    /// Mixed grocery list with weekly and urgent items
    static func mixedGroceryList() -> [GroceryItem] {
        let weeklyItems = [
            GroceryItem(
                ingredient: Ingredient(name: "Milk", quantity: "1", unit: "gallon", emoji: "🥛", category: .dairy),
                linkedMeal: "Breakfast cereals",
                addedBy: "Sarah",
                addedDate: Date().addingTimeInterval(-3600),
                isUrgent: false,
                notes: nil
            ),
            GroceryItem(
                ingredient: Ingredient(name: "Bread", quantity: "2", unit: "loaves", emoji: "🍞", category: .pantry),
                linkedMeal: "Sandwiches & Toast",
                addedBy: "System",
                addedDate: Date().addingTimeInterval(-7200),
                isUrgent: false,
                notes: nil
            ),
            GroceryItem(
                ingredient: Ingredient(name: "Bananas", quantity: "6", unit: "pieces", emoji: "🍌", category: .produce),
                linkedMeal: "Smoothies",
                addedBy: "Mike",
                addedDate: Date().addingTimeInterval(-1800),
                isUrgent: false,
                notes: nil
            )
        ]
        
        let urgentItems = [
            GroceryItem(
                ingredient: Ingredient(name: "Diapers", quantity: "1", unit: "pack", emoji: "👶", category: .pantry),
                linkedMeal: nil,
                addedBy: "Sarah",
                addedDate: Date().addingTimeInterval(-900),
                isUrgent: true,
                notes: "Size 3, running low!"
            ),
            GroceryItem(
                ingredient: Ingredient(name: "Ibuprofen", quantity: "1", unit: "bottle", emoji: "💊", category: .pantry),
                linkedMeal: nil,
                addedBy: "Mike",
                addedDate: Date().addingTimeInterval(-600),
                isUrgent: true,
                notes: "For Emma's fever"
            )
        ]
        
        return weeklyItems + urgentItems
    }
    
    /// Large grocery list for testing performance
    static func largeGroceryList() -> [GroceryItem] {
        let ingredients = [
            ("Apples", "6", "pieces", "🍎", IngredientCategory.produce),
            ("Chicken breast", "2", "lbs", "🐔", IngredientCategory.meat),
            ("Rice", "5", "lbs", "🍚", IngredientCategory.pantry),
            ("Yogurt", "4", "cups", "🥛", IngredientCategory.dairy),
            ("Carrots", "2", "lbs", "🥕", IngredientCategory.produce),
            ("Pasta", "3", "boxes", "🍝", IngredientCategory.pantry),
            ("Cheese", "1", "block", "🧀", IngredientCategory.dairy),
            ("Broccoli", "2", "heads", "🥦", IngredientCategory.produce),
            ("Ground turkey", "1", "lb", "🦃", IngredientCategory.meat),
            ("Olive oil", "1", "bottle", "🫒", IngredientCategory.pantry),
            ("Eggs", "12", "pieces", "🥚", IngredientCategory.dairy),
            ("Spinach", "1", "bag", "🥬", IngredientCategory.produce),
            ("Salmon", "1", "lb", "🐟", IngredientCategory.meat),
            ("Quinoa", "2", "cups", "🌾", IngredientCategory.pantry),
            ("Bell peppers", "4", "pieces", "🫑", IngredientCategory.produce)
        ]
        
        let familyMembers = ["Sarah", "Mike", "Emma", "System"]
        let meals = ["Breakfast", "Lunch", "Dinner", "Snacks", nil]
        
        return ingredients.enumerated().map { index, ingredient in
            GroceryItem(
                ingredient: Ingredient(
                    name: ingredient.0,
                    quantity: ingredient.1,
                    unit: ingredient.2,
                    emoji: ingredient.3,
                    category: ingredient.4
                ),
                linkedMeal: meals.randomElement() ?? nil,
                addedBy: familyMembers.randomElement() ?? "System",
                addedDate: Date().addingTimeInterval(-Double.random(in: 300...7200)),
                isUrgent: index % 7 == 0, // Make every 7th item urgent
                notes: nil
            )
        }
    }
    
    // MARK: - Shopping Task Scenarios
    
    /// Diverse shopping tasks with different statuses and priorities
    static func diverseShoppingTasks() -> [ShoppingTask] {
        let groceryItems = mixedGroceryList()
        
        return [
            // Pending urgent task
            ShoppingTask(
                items: Array(groceryItems.filter { $0.isUrgent }),
                assignedTo: "Sarah",
                taskType: .shopRun,
                dueDate: Date().addingTimeInterval(3600), // 1 hour from now
                notes: "Pick up urgent items for Emma",
                location: TaskLocation(
                    name: "Woolworths Menlyn",
                    address: "Shop 123, Menlyn Park Shopping Centre",
                    latitude: -25.7845,
                    longitude: 28.2314,
                    type: .supermarket
                ),
                status: .pending,
                createdBy: "Mike"
            ),
            
            // In progress regular task
            ShoppingTask(
                items: Array(groceryItems.filter { !$0.isUrgent }.prefix(5)),
                assignedTo: "Mike",
                taskType: .schoolRunPlusShop,
                dueDate: Date().addingTimeInterval(86400), // Tomorrow
                notes: "Combine with school pickup",
                location: TaskLocation(
                    name: "Pick n Pay Hatfield",
                    address: "Corner of Burnett & Duncan Streets",
                    latitude: -25.7479,
                    longitude: 28.2293,
                    type: .supermarket
                ),
                status: .inProgress,
                createdBy: "Sarah"
            ),
            
            // Completed task
            ShoppingTask(
                items: Array(groceryItems.prefix(3)),
                assignedTo: "Emma",
                taskType: .shopRun,
                dueDate: Date().addingTimeInterval(-3600), // 1 hour ago
                notes: "First solo shopping trip!",
                location: TaskLocation(
                    name: "Checkers Lynnwood",
                    address: "Lynnwood Bridge Shopping Centre",
                    latitude: -25.7679,
                    longitude: 28.2767,
                    type: .supermarket
                ),
                status: .completed,
                createdBy: "Sarah"
            ),
            
            // Overdue task
            ShoppingTask(
                items: Array(groceryItems.suffix(4)),
                assignedTo: "Mike",
                taskType: .shopRun,
                dueDate: Date().addingTimeInterval(-7200), // 2 hours ago
                notes: "Weekend grocery run",
                location: nil,
                status: .pending,
                createdBy: "Sarah"
            )
        ]
    }
    
    /// Empty task list for testing empty states
    static func emptyTaskList() -> [ShoppingTask] {
        return []
    }
    
    // MARK: - Ingredient Scenarios
    
    /// Pantry check ingredients with mixed availability
    static func pantryCheckIngredients() -> [Ingredient] {
        return [
            Ingredient(name: "Flour", quantity: "2", unit: "cups", emoji: "🌾", isAvailableInPantry: true, category: .pantry),
            Ingredient(name: "Sugar", quantity: "1", unit: "cup", emoji: "🍯", isAvailableInPantry: true, category: .pantry),
            Ingredient(name: "Eggs", quantity: "3", unit: "large", emoji: "🥚", isAvailableInPantry: false, category: .dairy),
            Ingredient(name: "Butter", quantity: "1/2", unit: "cup", emoji: "🧈", isAvailableInPantry: false, category: .dairy),
            Ingredient(name: "Vanilla", quantity: "1", unit: "tsp", emoji: "🌿", isAvailableInPantry: true, category: .pantry),
            Ingredient(name: "Baking powder", quantity: "2", unit: "tsp", emoji: "🥄", isAvailableInPantry: false, category: .pantry),
            Ingredient(name: "Milk", quantity: "1", unit: "cup", emoji: "🥛", isAvailableInPantry: false, category: .dairy),
            Ingredient(name: "Salt", quantity: "1", unit: "pinch", emoji: "🧂", isAvailableInPantry: true, category: .pantry)
        ]
    }
    
    // MARK: - Platform Scenarios
    
    /// Grocery delivery platforms with realistic data
    static func groceryPlatforms() -> [GroceryPlatform] {
        return [
            GroceryPlatform(
                name: "Woolworths Dash",
                description: "Fresh groceries delivered fast",
                logoName: "woolworths-logo",
                deliveryTime: "2-3 hours",
                minimumOrder: 150.0,
                deliveryFee: 35.0
            ),
            GroceryPlatform(
                name: "Checkers Sixty60",
                description: "Delivery within 60 minutes",
                logoName: "checkers-logo",
                deliveryTime: "45-60 minutes",
                minimumOrder: 200.0,
                deliveryFee: 45.0
            ),
            GroceryPlatform(
                name: "Pick n Pay asap!",
                description: "Same day delivery service",
                logoName: "picknpay-logo",
                deliveryTime: "3-5 hours",
                minimumOrder: 100.0,
                deliveryFee: 25.0
            ),
            GroceryPlatform(
                name: "Spar2U",
                description: "Local convenience delivery",
                logoName: "spar-logo",
                deliveryTime: "1-2 hours",
                minimumOrder: 80.0,
                deliveryFee: 20.0
            )
        ]
    }
    
    // MARK: - AppState Scenarios
    
    /// Create AppState with HomeLife data loaded
    @MainActor
    static func createHomeLifeAppState() -> AppState {
        let appState = AppState()
        let familyData = smallFamily()
        
        // Set up family context
        appState.currentFamily = familyData.family
        appState.currentUser = familyData.users[0]
        appState.currentMembership = familyData.memberships[0]
        
        // Load HomeLife data
        appState.currentMealPlan = weeklyMealPlan()
        appState.groceryList = mixedGroceryList()
        appState.shoppingTasks = diverseShoppingTasks()
        
        return appState
    }
    
    /// Create AppState with loading states
    @MainActor
    static func createLoadingAppState() -> AppState {
        let appState = AppState()
        let familyData = smallFamily()
        
        appState.currentFamily = familyData.family
        appState.currentUser = familyData.users[0]
        appState.currentMembership = familyData.memberships[0]
        
        // Set loading states
        appState.homeLifeIsLoading = true
        
        return appState
    }
    
    /// Create AppState with error states
    @MainActor
    static func createErrorAppState() -> AppState {
        let appState = AppState()
        let familyData = smallFamily()
        
        appState.currentFamily = familyData.family
        appState.currentUser = familyData.users[0]
        appState.currentMembership = familyData.memberships[0]
        
        // Set error state
        appState.homeLifeErrorMessage = "Failed to load meal plan. Please check your internet connection and try again."
        
        return appState
    }
}

// MARK: - Preview Environment Extensions

extension View {
    /// Apply HomeLife-specific preview environment with realistic data
    func homeLifePreviewEnvironment() -> some View {
        self.environmentObject(HomeLifePreviewProvider.createHomeLifeAppState())
    }
    
    /// Apply HomeLife preview environment with loading state
    func homeLifePreviewEnvironmentLoading() -> some View {
        self.environmentObject(HomeLifePreviewProvider.createLoadingAppState())
    }
    
    /// Apply HomeLife preview environment with error state
    func homeLifePreviewEnvironmentError() -> some View {
        self.environmentObject(HomeLifePreviewProvider.createErrorAppState())
    }
}