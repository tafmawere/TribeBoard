import SwiftUI

/// Dashboard view for displaying monthly meal plans with calendar/list toggle and pantry check navigation
struct MealPlanDashboardView: View {
    @StateObject private var viewModel = MealPlanViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Month selector and view mode toggle
                    headerControls
                    
                    // Meal cards
                    mealCardsSection
                    
                    Spacer(minLength: DesignSystem.Spacing.xxl)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.top, DesignSystem.Spacing.md)
            }
            .navigationTitle("Meal Plan")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .refreshable {
                await viewModel.loadMealPlan()
            }
        }
        .task {
            await viewModel.loadMealPlan()
        }
        .onAppear {
            if viewModel.currentMealPlan == nil {
                Task {
                    await viewModel.loadMealPlan()
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                LoadingStateView(
                    message: "Loading meal plan...",
                    style: .overlay
                )
                .transition(.opacity)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearErrorMessage()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Controls
    
    @ViewBuilder
    private var headerControls: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Month selector
            monthSelector
            
            // View mode toggle
            viewModeToggle
        }
    }
    
    @ViewBuilder
    private var monthSelector: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.brandPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.brandPrimary.opacity(0.1))
                    )
            }
            .accessibilityLabel("Previous month")
            
            Spacer()
            
            Text(monthYearString)
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundColor(.primary)
                .animation(.none, value: viewModel.selectedMonth)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.brandPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.brandPrimary.opacity(0.1))
                    )
            }
            .accessibilityLabel("Next month")
        }
    }
    
    @ViewBuilder
    private var viewModeToggle: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ForEach(MealViewMode.allCases, id: \.self) { mode in
                viewModeButton(for: mode)
            }
        }
    }
    
    @ViewBuilder
    private func viewModeButton(for mode: MealViewMode) -> some View {
        Button(action: {
            withAnimation(DesignSystem.Animation.quick) {
                viewModel.changeViewMode(to: mode)
            }
            HapticManager.shared.selection()
        }) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: mode.icon)
                    .font(DesignSystem.Typography.labelMedium)
                
                Text(mode.rawValue)
                    .font(DesignSystem.Typography.labelMedium)
            }
            .foregroundColor(viewModel.viewMode == mode ? .white : .brandPrimary)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(viewModel.viewMode == mode ? Color.brandPrimary : Color.brandPrimary.opacity(0.1))
            )
        }
        .accessibilityLabel("\(mode.rawValue) view")
        .accessibilityAddTraits(viewModel.viewMode == mode ? [.isSelected] : [])
    }
    
    // MARK: - Meal Cards Section
    
    @ViewBuilder
    private var mealCardsSection: some View {
        LazyVStack(spacing: DesignSystem.Spacing.lg) {
            if viewModel.mealsForSelectedMonth.isEmpty {
                emptyStateView
            } else {
                ForEach(groupedMeals, id: \.key) { dateGroup in
                    mealDaySection(for: dateGroup.key, meals: dateGroup.value)
                }
            }
        }
    }
    
    @ViewBuilder
    private func mealDaySection(for date: Date, meals: [PlannedMeal]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Date header
            HStack {
                Text(dayHeaderString(for: date))
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(dateString(for: date))
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(.secondary)
            }
            
            // Meal cards for this day
            ForEach(meals) { meal in
                MealCard(
                    meal: meal,
                    onCheckPantry: {
                        checkPantryForMeal(meal)
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.brandPrimary.opacity(0.6))
                .accessibilityHidden(true)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No Meals Planned")
                    .font(DesignSystem.Typography.headlineSmall)
                    .foregroundColor(.primary)
                
                Text("Start planning your family meals for this month")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    await viewModel.loadMealPlan()
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "plus.circle.fill")
                        .font(DesignSystem.Typography.labelMedium)
                    
                    Text("Add Meals")
                        .font(DesignSystem.Typography.labelMedium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .fill(LinearGradient.brandGradient)
                )
            }
            .accessibilityLabel("Add meals to meal plan")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxxl)
    }
    
    // MARK: - Computed Properties
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: viewModel.selectedMonth)
    }
    
    private var groupedMeals: [(key: Date, value: [PlannedMeal])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.mealsForSelectedMonth) { meal in
            calendar.startOfDay(for: meal.date)
        }
        
        return grouped.sorted { $0.key < $1.key }
    }
    
    // MARK: - Helper Methods
    
    private func dayHeaderString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func previousMonth() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: -1, to: viewModel.selectedMonth) {
            withAnimation(DesignSystem.Animation.smooth) {
                viewModel.changeMonth(to: newDate)
            }
            HapticManager.shared.selection()
        }
    }
    
    private func nextMonth() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: 1, to: viewModel.selectedMonth) {
            withAnimation(DesignSystem.Animation.smooth) {
                viewModel.changeMonth(to: newDate)
            }
            HapticManager.shared.selection()
        }
    }
    
    private func checkPantryForMeal(_ meal: PlannedMeal) {
        // Set the week for the meal's date
        let calendar = Calendar.current
        if let weekStart = calendar.dateInterval(of: .weekOfYear, for: meal.date)?.start {
            viewModel.changeWeek(to: weekStart)
        }
        
        HapticManager.shared.selection()
        // Navigation will be handled by NavigationLink in the MealCard
    }
}

// MARK: - Meal Card Component

/// Individual meal card showing meal details and pantry check button
struct MealCard: View {
    let meal: PlannedMeal
    let onCheckPantry: () -> Void
    
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Meal header
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(meal.mealType.emoji)
                            .font(DesignSystem.Typography.titleSmall)
                            .accessibilityHidden(true)
                        
                        Text(meal.name)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        Label("\(meal.servings) servings", systemImage: "person.2.fill")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(.secondary)
                        
                        Label("\(meal.estimatedPrepTime) min", systemImage: "clock.fill")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Ingredients list
            ingredientsList
            
            // Check pantry button
            checkPantryButton
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
        )
        .mediumShadow()
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(
            reduceMotion ? .none : DesignSystem.Animation.quick,
            value: isPressed
        )
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Meal: \(meal.name), \(meal.mealType.rawValue), \(meal.servings) servings, \(meal.estimatedPrepTime) minutes prep time")
    }
    
    @ViewBuilder
    private var ingredientsList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Ingredients:")
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: ingredientColumns, alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                ForEach(meal.ingredients.prefix(6)) { ingredient in
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(ingredient.emoji)
                            .font(DesignSystem.Typography.captionMedium)
                            .accessibilityHidden(true)
                        
                        Text(ingredient.name)
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundColor(.primary)
                        
                        if !ingredient.displayQuantity.isEmpty {
                            Text("(\(ingredient.displayQuantity))")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if meal.ingredients.count > 6 {
                    Text("+ \(meal.ingredients.count - 6) more")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.brandPrimary)
                        .italic()
                }
            }
        }
    }
    
    @ViewBuilder
    private var checkPantryButton: some View {
        NavigationLink(destination: PantryCheckView()) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DesignSystem.Typography.labelMedium)
                
                Text("Check Pantry")
                    .font(DesignSystem.Typography.labelMedium)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                    .fill(LinearGradient.brandGradient)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(TapGesture().onEnded {
            onCheckPantry()
        })
        .accessibilityLabel("Check pantry for \(meal.name)")
        .accessibilityHint("Opens pantry check view for this meal's ingredients")
    }
    
    private var ingredientColumns: [GridItem] {
        [
            GridItem(.flexible(), alignment: .leading),
            GridItem(.flexible(), alignment: .leading)
        ]
    }
}



// MARK: - Preview

#Preview("Meal Plan Dashboard - With Data") {
    MealPlanDashboardView()
        .previewEnvironment(.authenticated)
}

#Preview("Meal Plan Dashboard - Loading") {
    MealPlanDashboardView()
        .previewEnvironmentLoading()
}

#Preview("Meal Plan Dashboard - Empty") {
    MealPlanDashboardView()
        .onAppear {
            // Simulate empty state by clearing meal plan
        }
        .previewEnvironment(.authenticated)
}

#Preview("Meal Plan Dashboard - Dark Mode") {
    MealPlanDashboardView()
        .previewEnvironment(.authenticated)
        .preferredColorScheme(.dark)
}

#Preview("Meal Plan Dashboard - Large Text") {
    MealPlanDashboardView()
        .previewEnvironment(.authenticated)
        .environment(\.sizeCategory, .extraExtraExtraLarge)
}

#Preview("Meal Plan Dashboard - iPad") {
    MealPlanDashboardView()
        .previewEnvironment(.authenticated)
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
}

#Preview("Meal Card - Breakfast") {
    let mockMeal = PlannedMeal(
        name: "Avocado Toast with Eggs",
        date: Date(),
        ingredients: [
            Ingredient(name: "Bread", quantity: "2", unit: "slices", emoji: "🍞", category: .pantry),
            Ingredient(name: "Avocado", quantity: "1", unit: "medium", emoji: "🥑", category: .produce),
            Ingredient(name: "Eggs", quantity: "2", unit: "large", emoji: "🥚", category: .dairy),
            Ingredient(name: "Salt", quantity: "1", unit: "pinch", emoji: "🧂", category: .pantry)
        ],
        servings: 2,
        mealType: .breakfast,
        estimatedPrepTime: 15
    )
    
    MealCard(meal: mockMeal, onCheckPantry: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewEnvironment(.authenticated)
}

#Preview("Meal Card - Dinner") {
    let mockMeal = PlannedMeal(
        name: "Spaghetti Bolognese",
        date: Date(),
        ingredients: [
            Ingredient(name: "Spaghetti pasta", quantity: "1", unit: "box", emoji: "🍝", category: .pantry),
            Ingredient(name: "Ground beef", quantity: "1", unit: "lb", emoji: "🥩", category: .meat),
            Ingredient(name: "Tomatoes", quantity: "4", unit: "medium", emoji: "🍅", category: .produce),
            Ingredient(name: "Onion", quantity: "1", unit: "large", emoji: "🧅", category: .produce),
            Ingredient(name: "Garlic", quantity: "3", unit: "cloves", emoji: "🧄", category: .produce),
            Ingredient(name: "Olive oil", quantity: "2", unit: "tbsp", emoji: "🫒", category: .pantry),
            Ingredient(name: "Parmesan cheese", quantity: "1/2", unit: "cup", emoji: "🧀", category: .dairy)
        ],
        servings: 4,
        mealType: .dinner,
        estimatedPrepTime: 45
    )
    
    MealCard(meal: mockMeal, onCheckPantry: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewEnvironment(.authenticated)
}

#Preview("Meal Card - Dark Mode") {
    let mockMeal = PlannedMeal(
        name: "Chicken Stir Fry",
        date: Date(),
        ingredients: [
            Ingredient(name: "Chicken breast", quantity: "1", unit: "lb", emoji: "🐔", category: .meat),
            Ingredient(name: "Broccoli", quantity: "2", unit: "cups", emoji: "🥦", category: .produce),
            Ingredient(name: "Bell peppers", quantity: "2", unit: "medium", emoji: "🫑", category: .produce),
            Ingredient(name: "Soy sauce", quantity: "3", unit: "tbsp", emoji: "🥢", category: .pantry)
        ],
        servings: 3,
        mealType: .lunch,
        estimatedPrepTime: 30
    )
    
    MealCard(meal: mockMeal, onCheckPantry: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewEnvironment(.authenticated)
        .preferredColorScheme(.dark)
}

#Preview("Empty State") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        Image(systemName: "calendar.badge.plus")
            .font(.system(size: 64))
            .foregroundColor(.brandPrimary.opacity(0.6))
        
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("No Meals Planned")
                .headlineSmall()
                .foregroundColor(.primary)
            
            Text("Start planning your family meals for this month")
                .bodyMedium()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .previewEnvironment(.authenticated)
}