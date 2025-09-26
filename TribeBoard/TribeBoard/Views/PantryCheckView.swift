import SwiftUI

/// View for checking pantry inventory with interactive checkboxes and grocery list generation
struct PantryCheckView: View {
    @StateObject private var viewModel = MealPlanViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var showingGroceryList = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Week selector and progress
                    headerSection
                    
                    // Ingredients checklist
                    ingredientsSection
                    
                    // Generate grocery list button
                    generateGroceryListButton
                    
                    Spacer(minLength: DesignSystem.Spacing.xxl)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.top, DesignSystem.Spacing.md)
            }
            .navigationTitle("Pantry Check")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        resetPantryCheck()
                    }
                    .foregroundColor(.brandPrimary)
                }
            }
        }
        .task {
            if viewModel.currentMealPlan == nil {
                await viewModel.loadMealPlan()
            }
            viewModel.loadIngredientsForWeek()
        }
        .sheet(isPresented: $showingGroceryList) {
            // TODO: Navigate to GroceryListView in future task
            GroceryListPlaceholderView()
        }
        .overlay {
            if viewModel.isLoading {
                LoadingStateView(
                    message: "Loading ingredients...",
                    style: .overlay
                )
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Week selector
            weekSelector
            
            // Progress indicator
            progressIndicator
        }
    }
    
    @ViewBuilder
    private var weekSelector: some View {
        HStack {
            Button(action: previousWeek) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.brandPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.brandPrimary.opacity(0.1))
                    )
            }
            .accessibilityLabel("Previous week")
            
            Spacer()
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("Week of")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundColor(.secondary)
                
                Text(weekRangeString)
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(.primary)
                    .animation(.none, value: viewModel.selectedWeekStartDate)
            }
            
            Spacer()
            
            Button(action: nextWeek) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.brandPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.brandPrimary.opacity(0.1))
                    )
            }
            .accessibilityLabel("Next week")
        }
    }
    
    @ViewBuilder
    private var progressIndicator: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Pantry Check Progress")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(viewModel.checkedIngredientsCount) of \(viewModel.totalIngredientsCount)")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(.brandPrimary)
                    .fontWeight(.semibold)
            }
            
            ProgressView(value: viewModel.pantryCheckProgress)
                .tint(.brandPrimary)
                .scaleEffect(y: 1.5)
                .animation(DesignSystem.Animation.smooth, value: viewModel.pantryCheckProgress)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
        )
        .lightShadow()
    }
    
    // MARK: - Ingredients Section
    
    @ViewBuilder
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Ingredients Needed")
                    .font(DesignSystem.Typography.headlineSmall)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !viewModel.weekIngredients.isEmpty {
                    Text("\(viewModel.weekIngredients.count) items")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.weekIngredients.isEmpty {
                emptyIngredientsView
            } else {
                ingredientsList
            }
        }
    }
    
    @ViewBuilder
    private var ingredientsList: some View {
        LazyVStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(groupedIngredients, id: \.key) { categoryGroup in
                ingredientCategorySection(
                    category: categoryGroup.key,
                    ingredients: categoryGroup.value
                )
            }
        }
    }
    
    @ViewBuilder
    private func ingredientCategorySection(category: IngredientCategory, ingredients: [Ingredient]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Category header
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text(category.emoji)
                    .font(DesignSystem.Typography.labelMedium)
                    .accessibilityHidden(true)
                
                Text(category.rawValue)
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(ingredients.count)")
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                    )
            }
            
            // Ingredients in category
            ForEach(ingredients) { ingredient in
                IngredientCheckRow(
                    ingredient: ingredient,
                    onToggle: {
                        toggleIngredient(ingredient)
                    }
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
        )
        .lightShadow()
    }
    
    @ViewBuilder
    private var emptyIngredientsView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "basket")
                .font(.system(size: 48))
                .foregroundColor(.brandPrimary.opacity(0.6))
                .accessibilityHidden(true)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No Ingredients This Week")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(.primary)
                
                Text("No meals are planned for this week")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxxl)
    }
    
    // MARK: - Generate Grocery List Button
    
    @ViewBuilder
    private var generateGroceryListButton: some View {
        if !viewModel.weekIngredients.isEmpty {
            VStack(spacing: DesignSystem.Spacing.md) {
                Button(action: generateGroceryList) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "cart.badge.plus")
                            .font(DesignSystem.Typography.titleSmall)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Generate Grocery List")
                                .font(DesignSystem.Typography.titleSmall)
                                .fontWeight(.semibold)
                            
                            if viewModel.missingIngredients.count > 0 {
                                Text("\(viewModel.missingIngredients.count) items needed")
                                    .font(DesignSystem.Typography.captionMedium)
                                    .opacity(0.9)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(DesignSystem.Typography.labelMedium)
                    }
                    .foregroundColor(.white)
                    .padding(DesignSystem.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                            .fill(
                                viewModel.missingIngredients.isEmpty 
                                ? LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient.brandGradient
                            )
                    )
                    .scaleEffect(viewModel.missingIngredients.isEmpty ? 0.95 : 1.0)
                    .animation(DesignSystem.Animation.quick, value: viewModel.missingIngredients.isEmpty)
                }
                .disabled(viewModel.missingIngredients.isEmpty)
                .accessibilityLabel("Generate grocery list")
                .accessibilityHint(viewModel.missingIngredients.isEmpty ? "All ingredients are available" : "Creates grocery list with \(viewModel.missingIngredients.count) missing items")
                
                if viewModel.isPantryCheckComplete {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundColor(.green)
                        
                        Text("All ingredients available!")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var weekRangeString: String {
        viewModel.getWeekRangeString(for: viewModel.selectedWeekStartDate)
    }
    
    private var groupedIngredients: [(key: IngredientCategory, value: [Ingredient])] {
        let grouped = Dictionary(grouping: viewModel.weekIngredients) { $0.category }
        return grouped.sorted { $0.key.rawValue < $1.key.rawValue }
    }
    
    // MARK: - Actions
    
    private func previousWeek() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: viewModel.selectedWeekStartDate) {
            withAnimation(DesignSystem.Animation.smooth) {
                viewModel.changeWeek(to: newDate)
            }
            HapticManager.shared.selection()
        }
    }
    
    private func nextWeek() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: viewModel.selectedWeekStartDate) {
            withAnimation(DesignSystem.Animation.smooth) {
                viewModel.changeWeek(to: newDate)
            }
            HapticManager.shared.selection()
        }
    }
    
    private func toggleIngredient(_ ingredient: Ingredient) {
        withAnimation(DesignSystem.Animation.quick) {
            viewModel.toggleIngredientAvailability(ingredient)
        }
        
        // Haptic feedback based on action
        if ingredient.isAvailableInPantry {
            HapticManager.shared.lightImpact() // Unchecking
        } else {
            HapticManager.shared.success() // Checking
        }
    }
    
    private func resetPantryCheck() {
        withAnimation(DesignSystem.Animation.smooth) {
            viewModel.resetPantryCheck()
        }
        HapticManager.shared.mediumImpact()
    }
    
    private func generateGroceryList() {
        guard !viewModel.missingIngredients.isEmpty else { return }
        
        HapticManager.shared.success()
        showingGroceryList = true
    }
}

// MARK: - Ingredient Check Row

/// Individual ingredient row with checkbox and details
struct IngredientCheckRow: View {
    let ingredient: Ingredient
    let onToggle: () -> Void
    
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            ingredient.isAvailableInPantry ? Color.brandPrimary : Color.secondary.opacity(0.5),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ingredient.isAvailableInPantry ? Color.brandPrimary : Color.clear)
                        )
                    
                    if ingredient.isAvailableInPantry {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(DesignSystem.Animation.quick, value: ingredient.isAvailableInPantry)
                
                // Ingredient details
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(ingredient.emoji)
                        .font(DesignSystem.Typography.bodyMedium)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ingredient.name)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(.primary)
                            .strikethrough(ingredient.isAvailableInPantry)
                            .animation(.none, value: ingredient.isAvailableInPantry)
                        
                        if !ingredient.displayQuantity.isEmpty {
                            Text(ingredient.displayQuantity)
                                .font(DesignSystem.Typography.captionMedium)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                    .fill(ingredient.isAvailableInPantry ? Color.brandPrimary.opacity(0.05) : Color.clear)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(
                reduceMotion ? .none : DesignSystem.Animation.quick,
                value: isPressed
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ingredient.name), \(ingredient.displayQuantity)")
        .accessibilityValue(ingredient.isAvailableInPantry ? "Available in pantry" : "Not available")
        .accessibilityHint("Double tap to toggle availability")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Grocery List Placeholder

/// Placeholder view for grocery list (to be replaced in future task)
struct GroceryListPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.brandPrimary)
                    .accessibilityHidden(true)
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Grocery List")
                        .font(DesignSystem.Typography.headlineLarge)
                        .foregroundColor(.primary)
                    
                    Text("This will be the grocery list view")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.brandPrimary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Grocery List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Pantry Check View - With Data") {
    PantryCheckView()
        .previewEnvironment(.authenticated)
}

#Preview("Pantry Check View - Empty") {
    PantryCheckView()
        .onAppear {
            // Simulate empty state by clearing ingredients
        }
        .previewEnvironment(.authenticated)
}

#Preview("Pantry Check View - Loading") {
    PantryCheckView()
        .previewEnvironmentLoading()
}

#Preview("Pantry Check View - Dark Mode") {
    PantryCheckView()
        .previewEnvironment(.authenticated)
        .preferredColorScheme(.dark)
}

#Preview("Pantry Check View - Large Text") {
    PantryCheckView()
        .previewEnvironment(.authenticated)
        .environment(\.sizeCategory, .extraExtraExtraLarge)
}

#Preview("Pantry Check View - iPad") {
    PantryCheckView()
        .previewEnvironment(.authenticated)
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
}

#Preview("Ingredient Check Row - Available") {
    let ingredient = Ingredient(
        name: "Carrots",
        quantity: "2",
        unit: "cups",
        emoji: "🥕",
        isAvailableInPantry: true,
        category: .produce
    )
    
    IngredientCheckRow(ingredient: ingredient, onToggle: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewEnvironment(.authenticated)
}

#Preview("Ingredient Check Row - Not Available") {
    let ingredient = Ingredient(
        name: "Ground Beef",
        quantity: "1",
        unit: "lb",
        emoji: "🥩",
        isAvailableInPantry: false,
        category: .meat
    )
    
    IngredientCheckRow(ingredient: ingredient, onToggle: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewEnvironment(.authenticated)
}

#Preview("Ingredient Check Row - Dark Mode") {
    let ingredient = Ingredient(
        name: "Olive Oil",
        quantity: "3",
        unit: "tbsp",
        emoji: "🫒",
        isAvailableInPantry: false,
        category: .pantry
    )
    
    IngredientCheckRow(ingredient: ingredient, onToggle: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewEnvironment(.authenticated)
        .preferredColorScheme(.dark)
}

#Preview("Progress Indicator - Partial") {
    VStack(spacing: DesignSystem.Spacing.sm) {
        HStack {
            Text("Pantry Check Progress")
                .labelMedium()
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("3 of 8")
                .labelMedium()
                .foregroundColor(.brandPrimary)
                .fontWeight(.semibold)
        }
        
        ProgressView(value: 0.375)
            .tint(.brandPrimary)
            .scaleEffect(y: 1.5)
    }
    .padding(DesignSystem.Spacing.lg)
    .background(
        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
            .fill(Color(.systemBackground))
    )
    .lightShadow()
    .padding()
    .background(Color(.systemGroupedBackground))
    .previewEnvironment(.authenticated)
}

#Preview("Progress Indicator - Complete") {
    VStack(spacing: DesignSystem.Spacing.sm) {
        HStack {
            Text("Pantry Check Progress")
                .labelMedium()
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("8 of 8")
                .labelMedium()
                .foregroundColor(.green)
                .fontWeight(.semibold)
        }
        
        ProgressView(value: 1.0)
            .tint(.green)
            .scaleEffect(y: 1.5)
    }
    .padding(DesignSystem.Spacing.lg)
    .background(
        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
            .fill(Color(.systemBackground))
    )
    .lightShadow()
    .padding()
    .background(Color(.systemGroupedBackground))
    .previewEnvironment(.authenticated)
}

#Preview("Grocery List Placeholder") {
    GroceryListPlaceholderView()
        .previewEnvironment(.authenticated)
}