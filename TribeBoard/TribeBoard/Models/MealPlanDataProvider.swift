import Foundation

/// Provides mock data for meal planning, grocery lists, and shopping tasks
struct MealPlanDataProvider {
    
    // MARK: - Mock Meal Plan Data
    
    /// Generates a realistic monthly meal plan for a family
    static func mockMealPlan() -> MealPlan {
        let calendar = Calendar.current
        let today = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        
        let meals = generateMealsForMonth(startDate: startOfMonth)
        
        return MealPlan(
            month: startOfMonth,
            meals: meals
        )
    }
    
    /// Generates meals for a full month
    private static func generateMealsForMonth(startDate: Date) -> [PlannedMeal] {
        let calendar = Calendar.current
        var meals: [PlannedMeal] = []
        
        // Generate meals for 30 days
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            
            // Generate 1-2 meals per day (focusing on dinner, sometimes lunch)
            let dailyMeals = generateMealsForDay(date: date)
            meals.append(contentsOf: dailyMeals)
        }
        
        return meals
    }
    
    /// Generates meals for a specific day
    private static func generateMealsForDay(date: Date) -> [PlannedMeal] {
        let mealOptions = [
            ("Spaghetti Bolognese", mockSpaghettiIngredients(), 4, 45),
            ("Chicken Stir Fry", mockStirFryIngredients(), 4, 30),
            ("Beef Tacos", mockTacoIngredients(), 6, 25),
            ("Salmon with Rice", mockSalmonIngredients(), 4, 35),
            ("Vegetable Curry", mockCurryIngredients(), 5, 40),
            ("Grilled Chicken Salad", mockSaladIngredients(), 4, 20),
            ("Pasta Primavera", mockPrimaverIngredients(), 4, 30),
            ("Beef Stew", mockStewIngredients(), 6, 60),
            ("Fish and Chips", mockFishChipsIngredients(), 4, 35),
            ("Chicken Quesadillas", mockQuesadillaIngredients(), 4, 20)
        ]
        
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: date)
        
        // Weekend meals might be more elaborate
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        let mealCount = isWeekend ? Int.random(in: 1...2) : 1
        
        var dailyMeals: [PlannedMeal] = []
        
        for mealIndex in 0..<mealCount {
            let randomMeal = mealOptions.randomElement()!
            let mealTime: MealType = mealIndex == 0 ? .dinner : .lunch
            
            let meal = PlannedMeal(
                name: randomMeal.0,
                date: date,
                ingredients: randomMeal.1,
                servings: randomMeal.2,
                mealType: mealTime,
                estimatedPrepTime: randomMeal.3
            )
            
            dailyMeals.append(meal)
        }
        
        return dailyMeals
    }
    
    // MARK: - Ingredient Collections
    
    private static func mockSpaghettiIngredients() -> [Ingredient] {
        return [
            Ingredient(name: "Spaghetti pasta", quantity: "1", unit: "box", emoji: "🍝", category: .pantry),
            Ingredient(name: "Ground beef", quantity: "1", unit: "lb", emoji: "🥩", category: .meat),
            Ingredient(name: "Tomatoes", quantity: "4", unit: "medium", emoji: "🍅", category: .produce),
            Ingredient(name: "Onion", quantity: "1", unit: "large", emoji: "🧅", category: .produce),
            Ingredient(name: "Garlic", quantity: "3", unit: "cloves", emoji: "🧄", category: .produce),
            Ingredient(name: "Olive oil", quantity: "2", unit: "tbsp", emoji: "🫒", category: .pantry),
            Ingredient(name: "Parmesan cheese", quantity: "1", unit: "cup", emoji: "🧀", category: .dairy)
        ]
    }
    
    private static func mockStirFryIngredients() -> [Ingredient] {
        return [
            Ingredient(name: "Chicken breast", quantity: "2", unit: "lbs", emoji: "🐔", category: .meat),
            Ingredient(name: "Broccoli", quantity: "2", unit: "cups", emoji: "🥦", category: .produce),
            Ingredient(name: "Bell peppers", quantity: "2", unit: "medium", emoji: "🫑", category: .produce),
            Ingredient(name: "Carrots", quantity: "3", unit: "medium", emoji: "🥕", category: .produce),
            Ingredient(name: "Soy sauce", quantity: "3", unit: "tbsp", emoji: "🥢", category: .pantry),
            Ingredient(name: "Rice", quantity: "2", unit: "cups", emoji: "🍚", category: .pantry),
            Ingredient(name: "Ginger", quantity: "1", unit: "inch", emoji: "🫚", category: .spices)
        ]
    }
    
    private static func mockTacoIngredients() -> [Ingredient] {
        return [
            Ingredient(name: "Ground turkey", quantity: "1.5", unit: "lbs", emoji: "🦃", category: .meat),
            Ingredient(name: "Taco shells", quantity: "12", unit: "count", emoji: "🌮", category: .pantry),
            Ingredient(name: "Lettuce", quantity: "1", unit: "head", emoji: "🥬", category: .produce),
            Ingredient(name: "Tomatoes", quantity: "3", unit: "medium", emoji: "🍅", category: .produce),
            Ingredient(name: "Cheddar cheese", quantity: "2", unit: "cups", emoji: "🧀", category: .dairy),
            Ingredient(name: "Sour cream", quantity: "1", unit: "container", emoji: "🥛", category: .dairy),
            Ingredient(name: "Avocado", quantity: "2", unit: "medium", emoji: "🥑", category: .produce)
        ]
    }
    
    private static func mockSalmonIngredients() -> [Ingredient] {
        return [
            Ingredient(name: "Salmon fillets", quantity: "4", unit: "pieces", emoji: "🐟", category: .meat),
            Ingredient(name: "Jasmine rice", quantity: "1.5", unit: "cups", emoji: "🍚", category: .pantry),
            Ingredient(name: "Asparagus", quantity: "1", unit: "bunch", emoji: "🥒", category: .produce),
            Ingredient(name: "Lemon", quantity: "2", unit: "medium", emoji: "🍋", category: .produce),
            Ingredient(name: "Butter", quantity: "4", unit: "tbsp", emoji: "🧈", category: .dairy),
            Ingredient(name: "Dill", quantity: "2", unit: "tbsp", emoji: "🌿", category: .spices)
        ]
    }
    
    private static func mockCurryIngredients() -> [Ingredient] {
        return [
            Ingredient(name: "Chickpeas", quantity: "2", unit: "cans", emoji: "🫘", category: .pantry),
            Ingredient(name: "Coconut milk", quantity: "1", unit: "can", emoji: "🥥", category: .pantry),
            Ingredient(name: "Sweet potatoes", quantity: "3", unit: "medium", emoji: "🍠", category: .produce),
            Ingredient(name: "Spinach", quantity: "4", unit: "cups", emoji: "🥬", category: .produce),
            Ingredient(name: "Curry powder", quantity: "2", unit: "tbsp", emoji: "🌶️", category: .spices),
            Ingredient(name: "Basmati rice", quantity: "1.5", unit: "cups", emoji: "🍚", category: .pantry),
            Ingredient(name: "Onion", quantity: "1", unit: "large", emoji: "🧅", category: .produce)
        ]
    }
    
    private static func mockSaladIngredients() -> [Ingredient] {
        return [
            Ingredient(name: "Chicken breast", quantity: "2", unit: "lbs", emoji: "🐔", category: .meat),
            Ingredient(name: "Mixed greens", quantity: "6", unit: "cups", emoji: "🥗", category: .produce),
            Ingredient(name: "Cherry tomatoes", quantity: "2", unit: "cups", emoji: "🍅", category: .produce),
            Ingredient(name: "Cucumber", quantity: "1", unit: "large", emoji: "🥒", category: .produce),
            Ingredient(name: "Feta cheese", quantity: "1", unit: "cup", emoji: "🧀", category: .dairy),
            Ingredient(name: "Olive oil", quantity: "3", unit: "tbsp", emoji: "🫒", category: .pantry),
            Ingredient(name: "Balsamic vinegar", quantity: "2", unit: "tbsp", emoji: "🍶", category: .pantry)
        ]
    }
    
    private static func mockPrimaverIngredients() -> [Ingredient] {
        return [
            Ingredient(name: "Penne pasta", quantity: "1", unit: "box", emoji: "🍝", category: .pantry),
            Ingredient(name: "Zucchini", quantity: "2", unit: "medium", emoji: "🥒", category: .produce),
            Ingredient(name: "Yellow squash", quantity: "2", unit: "medium", emoji: "🥒", category: .produce),
            Ingredient(name: "Cherry tomatoes", quantity: "2", unit: "cups", emoji: "🍅", category: .produce),
            Ingredient(name: "Heavy cream", quantity: "1", unit: "cup", emoji: "🥛", category: .dairy),
            Ingredient(name: "Parmesan cheese", quantity: "1", unit: "cup", emoji: "🧀", category: .dairy),
            Ingredient(name: "Fresh basil", quantity: "1/4", unit: "cup", emoji: "🌿", category: .spices)
        ]
    }
    
    private static func mockStewIngredients() -> [Ingredient] {
        return [
            Ingredient(name: "Beef chuck", quantity: "2", unit: "lbs", emoji: "🥩", category: .meat),
            Ingredient(name: "Potatoes", quantity: "4", unit: "large", emoji: "🥔", category: .produce),
            Ingredient(name: "Carrots", quantity: "4", unit: "large", emoji: "🥕", category: .produce),
            Ingredient(name: "Celery", quantity: "3", unit: "stalks", emoji: "🥬", category: .produce),
            Ingredient(name: "Beef broth", quantity: "4", unit: "cups", emoji: "🍲", category: .pantry),
            Ingredient(name: "Onion", quantity: "1", unit: "large", emoji: "🧅", category: .produce),
            Ingredient(name: "Thyme", quantity: "2", unit: "tsp", emoji: "🌿", category: .spices)
        ]
    }
    
    private static func mockFishChipsIngredients() -> [Ingredient] {
        return [
            Ingredient(name: "White fish fillets", quantity: "4", unit: "pieces", emoji: "🐟", category: .meat),
            Ingredient(name: "Potatoes", quantity: "6", unit: "large", emoji: "🥔", category: .produce),
            Ingredient(name: "Flour", quantity: "2", unit: "cups", emoji: "🌾", category: .pantry),
            Ingredient(name: "Beer", quantity: "1", unit: "bottle", emoji: "🍺", category: .pantry),
            Ingredient(name: "Vegetable oil", quantity: "4", unit: "cups", emoji: "🫒", category: .pantry),
            Ingredient(name: "Peas", quantity: "2", unit: "cups", emoji: "🟢", category: .frozen),
            Ingredient(name: "Lemon", quantity: "2", unit: "medium", emoji: "🍋", category: .produce)
        ]
    }
    
    private static func mockQuesadillaIngredients() -> [Ingredient] {
        return [
            Ingredient(name: "Chicken breast", quantity: "1", unit: "lb", emoji: "🐔", category: .meat),
            Ingredient(name: "Flour tortillas", quantity: "8", unit: "large", emoji: "🌯", category: .pantry),
            Ingredient(name: "Monterey Jack cheese", quantity: "2", unit: "cups", emoji: "🧀", category: .dairy),
            Ingredient(name: "Bell peppers", quantity: "2", unit: "medium", emoji: "🫑", category: .produce),
            Ingredient(name: "Onion", quantity: "1", unit: "medium", emoji: "🧅", category: .produce),
            Ingredient(name: "Salsa", quantity: "1", unit: "jar", emoji: "🍅", category: .pantry),
            Ingredient(name: "Sour cream", quantity: "1", unit: "container", emoji: "🥛", category: .dairy)
        ]
    }
    
    // MARK: - Mock Grocery Items
    
    /// Generates mock grocery items from meal planning
    static func mockGroceryItems() -> [GroceryItem] {
        let mealPlan = mockMealPlan()
        let calendar = Calendar.current
        let today = Date()
        
        // Get ingredients for this week
        let weekIngredients = mealPlan.ingredients(for: today)
        
        // Convert some ingredients to grocery items (simulate pantry check)
        let groceryItems = weekIngredients.prefix(8).enumerated().map { index, ingredient in
            let isUrgent = index < 2 // First 2 items are urgent
            let linkedMeal = mealPlan.meals.first { $0.ingredients.contains { $0.name == ingredient.name } }?.name
            
            return GroceryItem(
                ingredient: ingredient,
                linkedMeal: linkedMeal,
                addedBy: isUrgent ? "Grace Mawere" : "System",
                addedDate: calendar.date(byAdding: .hour, value: -index, to: today) ?? today,
                isUrgent: isUrgent,
                notes: isUrgent ? "Running low!" : nil
            )
        }
        
        // Add some manual urgent items
        let urgentItems = [
            GroceryItem(
                ingredient: Ingredient(name: "Milk", quantity: "1", unit: "gallon", emoji: "🥛", category: .dairy),
                linkedMeal: nil,
                addedBy: "Ethan Mawere",
                addedDate: calendar.date(byAdding: .hour, value: -2, to: today) ?? today,
                isUrgent: true,
                notes: "We're almost out!"
            ),
            GroceryItem(
                ingredient: Ingredient(name: "Bread", quantity: "2", unit: "loaves", emoji: "🍞", category: .bakery),
                linkedMeal: nil,
                addedBy: "Tafadzwa Mawere",
                addedDate: calendar.date(byAdding: .hour, value: -4, to: today) ?? today,
                isUrgent: true,
                notes: "For school lunches"
            ),
            GroceryItem(
                ingredient: Ingredient(name: "Bananas", quantity: "6", unit: "count", emoji: "🍌", category: .produce),
                linkedMeal: nil,
                addedBy: "Zoe Mawere",
                addedDate: calendar.date(byAdding: .hour, value: -1, to: today) ?? today,
                isUrgent: false,
                notes: "For smoothies"
            )
        ]
        
        return Array(groceryItems) + urgentItems
    }
    
    // MARK: - Mock Shopping Tasks
    
    /// Generates mock shopping tasks with different types and statuses
    static func mockShoppingTasks() -> [ShoppingTask] {
        let groceryItems = mockGroceryItems()
        let calendar = Calendar.current
        let today = Date()
        
        // Get family member names (matching existing mock data)
        let familyMembers = ["Tafadzwa Mawere", "Grace Mawere", "Ethan Mawere", "Zoe Mawere"]
        
        return [
            ShoppingTask(
                items: Array(groceryItems.prefix(4)),
                assignedTo: "Grace Mawere",
                taskType: .shopRun,
                dueDate: calendar.date(byAdding: .hour, value: 3, to: today) ?? today,
                notes: "Pick up items for tonight's dinner",
                location: TaskLocation(
                    name: "Woolworths",
                    address: "123 Main Street",
                    latitude: -26.2041,
                    longitude: 28.0473,
                    type: .supermarket
                ),
                status: .pending,
                createdBy: "Tafadzwa Mawere"
            ),
            ShoppingTask(
                items: Array(groceryItems.suffix(3)),
                assignedTo: "Tafadzwa Mawere",
                taskType: .schoolRunPlusShop,
                dueDate: calendar.date(byAdding: .day, value: 1, to: today) ?? today,
                notes: "Stop by store after picking up kids",
                location: TaskLocation(
                    name: "Pick n Pay",
                    address: "456 School Road",
                    latitude: -26.2041,
                    longitude: 28.0473,
                    type: .supermarket
                ),
                status: .inProgress,
                createdBy: "Grace Mawere"
            ),
            ShoppingTask(
                items: [groceryItems.first { $0.isUrgent }!],
                assignedTo: "Ethan Mawere",
                taskType: .shopRun,
                dueDate: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
                notes: "Quick run for milk",
                location: TaskLocation(
                    name: "Local Spar",
                    address: "789 Corner Street",
                    latitude: -26.2041,
                    longitude: 28.0473,
                    type: .supermarket
                ),
                status: .completed,
                createdBy: "Grace Mawere"
            ),
            ShoppingTask(
                items: Array(groceryItems.filter { !$0.isUrgent }.prefix(2)),
                assignedTo: "Zoe Mawere",
                taskType: .shopRun,
                dueDate: calendar.date(byAdding: .day, value: 2, to: today) ?? today,
                notes: "Weekend shopping trip",
                location: nil,
                status: .pending,
                createdBy: "Tafadzwa Mawere"
            )
        ]
    }
    
    // MARK: - Mock Family Members
    
    /// Provides mock family member names for task assignment
    static func mockFamilyMembers() -> [String] {
        return ["Tafadzwa Mawere", "Grace Mawere", "Ethan Mawere", "Zoe Mawere", "Grandma Rose"]
    }
    
    // MARK: - Mock Grocery Platforms
    
    /// Provides mock grocery delivery platforms
    static func mockGroceryPlatforms() -> [GroceryPlatform] {
        return [
            GroceryPlatform(
                name: "Woolworths Dash",
                description: "Fast delivery in 2 hours",
                logoName: "woolworths-logo",
                deliveryTime: "2 hours",
                minimumOrder: 150.0,
                deliveryFee: 35.0
            ),
            GroceryPlatform(
                name: "Checkers Sixty60",
                description: "Delivery within 60 minutes",
                logoName: "checkers-logo",
                deliveryTime: "60 minutes",
                minimumOrder: 200.0,
                deliveryFee: 45.0
            ),
            GroceryPlatform(
                name: "Pick n Pay asap!",
                description: "Same day delivery",
                logoName: "picknpay-logo",
                deliveryTime: "Same day",
                minimumOrder: 100.0,
                deliveryFee: 25.0
            )
        ]
    }
}

/// Data model representing a grocery delivery platform
struct GroceryPlatform: Identifiable, Codable {
    let id = UUID()
    let name: String
    let description: String
    let logoName: String
    let deliveryTime: String
    let minimumOrder: Double
    let deliveryFee: Double
    
    /// Formatted minimum order amount
    var formattedMinimumOrder: String {
        return String(format: "R%.0f", minimumOrder)
    }
    
    /// Formatted delivery fee
    var formattedDeliveryFee: String {
        return String(format: "R%.0f", deliveryFee)
    }
}