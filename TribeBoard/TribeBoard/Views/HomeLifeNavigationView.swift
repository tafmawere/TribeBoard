import SwiftUI

/// Main navigation hub for HomeLife features including meal planning, grocery lists, tasks, and pantry management
struct HomeLifeNavigationView: View {
    @EnvironmentObject var appState: AppState
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $appState.homeLifeNavigationPath) {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header section
                    headerSection
                    
                    // Feature cards grid
                    featureCardsGrid
                    
                    Spacer(minLength: DesignSystem.Spacing.xxl)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.top, DesignSystem.Spacing.lg)
            }
            .navigationTitle("HomeLife")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .navigationDestination(for: HomeLifeTab.self) { tab in
                destinationView(for: tab)
            }
            .overlay {
                if appState.homeLifeIsLoading {
                    LoadingOverlay()
                }
            }
            .alert("HomeLife Error", isPresented: .constant(appState.homeLifeErrorMessage != nil)) {
                Button("OK") {
                    appState.clearHomeLifeError()
                }
            } message: {
                if let errorMessage = appState.homeLifeErrorMessage {
                    Text(errorMessage)
                }
            }
            .task {
                // Load HomeLife data when view appears
                await appState.loadHomeLifeMealPlan()
                await appState.loadShoppingTasks()
            }
            .onAppear {
                // Ensure data is loaded on appear as well
                if appState.currentMealPlan == nil {
                    Task {
                        await appState.loadHomeLifeMealPlan()
                    }
                }
                if appState.shoppingTasks.isEmpty {
                    Task {
                        await appState.loadShoppingTasks()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Welcome message
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Welcome to HomeLife")
                        .headlineLarge()
                        .foregroundColor(.primary)
                    
                    Text("Manage your family's meals, shopping, and household tasks")
                        .bodyMedium()
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Family context and HomeLife summary
            if let family = appState.currentFamily {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Managing \(family.name)")
                            .labelMedium()
                            .foregroundColor(.brandPrimary)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                                    .fill(Color.brandPrimary.opacity(0.1))
                            )
                        
                        Spacer()
                    }
                    
                    // HomeLife summary
                    let summary = appState.getHomeLifeSummary()
                    if summary.hasUrgentItems {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            
                            Text(summary.statusMessage)
                                .captionMedium()
                                .foregroundColor(.orange)
                            
                            Spacer()
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                                .fill(Color.orange.opacity(0.1))
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Feature Cards Grid
    
    @ViewBuilder
    private var featureCardsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: DesignSystem.Spacing.lg) {
            // Meal Plan Card
            HomeLifeFeatureCard(
                title: "Meal Plan",
                description: "Plan your family meals",
                icon: "🍽️",
                gradientColors: [.brandPrimary, .brandSecondary],
                action: {
                    HapticManager.shared.selection()
                    appState.navigateToHomeLifeTab(.mealPlan)
                    appState.homeLifeNavigationPath.append(HomeLifeTab.mealPlan)
                }
            )
            
            // Grocery List Card
            HomeLifeFeatureCard(
                title: "Grocery List",
                description: "Manage shopping lists",
                icon: "🛒",
                gradientColors: [.green, .mint],
                action: {
                    HapticManager.shared.selection()
                    appState.navigateToHomeLifeTab(.groceryList)
                    appState.homeLifeNavigationPath.append(HomeLifeTab.groceryList)
                }
            )
            
            // Tasks Card
            HomeLifeFeatureCard(
                title: "Tasks",
                description: "Assign shopping tasks",
                icon: "✅",
                gradientColors: [.orange, .yellow],
                action: {
                    HapticManager.shared.selection()
                    appState.navigateToHomeLifeTab(.tasks)
                    appState.homeLifeNavigationPath.append(HomeLifeTab.tasks)
                }
            )
            
            // Pantry Card
            HomeLifeFeatureCard(
                title: "Pantry",
                description: "Check what you have",
                icon: "📋",
                gradientColors: [.purple, .pink],
                action: {
                    HapticManager.shared.selection()
                    appState.navigateToHomeLifeTab(.pantry)
                    appState.homeLifeNavigationPath.append(HomeLifeTab.pantry)
                }
            )
        }
    }
    
    // MARK: - Navigation Destination
    
    @ViewBuilder
    private func destinationView(for tab: HomeLifeTab) -> some View {
        switch tab {
        case .mealPlan:
            MealPlanDashboardView()
                .environmentObject(appState)
        case .groceryList:
            GroceryListView()
                .environmentObject(appState)
        case .tasks:
            TaskListView()
                .environmentObject(appState)
        case .pantry:
            PantryCheckView()
                .environmentObject(appState)
        }
    }
    
    // MARK: - Grid Configuration
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
            GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
        ]
    }
}

// MARK: - HomeLife Feature Card

/// Individual feature card for HomeLife navigation
struct HomeLifeFeatureCard: View {
    let title: String
    let description: String
    let icon: String
    let gradientColors: [Color]
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            HapticManager.shared.selection()
            action()
        }) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Icon
                Text(icon)
                    .font(.system(size: 40))
                    .accessibilityHidden(true)
                
                // Title and description
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(title)
                        .titleMedium()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(description)
                        .captionMedium()
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .padding(DesignSystem.Spacing.lg)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge))
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(
                reduceMotion ? .none : DesignSystem.Animation.quick,
                value: isPressed
            )
            .shadow(
                color: gradientColors.first?.opacity(0.3) ?? .clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityLabel("\(title): \(description)")
        .accessibilityHint("Double tap to open \(title.lowercased())")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview("HomeLife Navigation View") {
    HomeLifeNavigationView()
        .previewEnvironment(.authenticated)
}

#Preview("HomeLife Navigation View - No Family") {
    HomeLifeNavigationView()
        .previewEnvironment(.unauthenticated)
}

#Preview("HomeLife Navigation View - Loading") {
    HomeLifeNavigationView()
        .previewEnvironmentLoading()
}

#Preview("HomeLife Navigation View - Parent Admin") {
    HomeLifeNavigationView()
        .previewEnvironment(role: .parentAdmin)
}

#Preview("HomeLife Navigation View - Kid") {
    HomeLifeNavigationView()
        .previewEnvironment(role: .kid)
}

#Preview("HomeLife Navigation View - Dark Mode") {
    HomeLifeNavigationView()
        .previewEnvironment(.authenticated)
        .preferredColorScheme(.dark)
}

#Preview("HomeLife Navigation View - Large Text") {
    HomeLifeNavigationView()
        .previewEnvironment(.authenticated)
        .environment(\.sizeCategory, .extraExtraExtraLarge)
}

#Preview("HomeLife Navigation View - iPad") {
    HomeLifeNavigationView()
        .previewEnvironment(.authenticated)
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
}

#Preview("HomeLife Navigation View - High Contrast") {
    HomeLifeNavigationView()
        .previewEnvironment(.authenticated)
}

#Preview("HomeLife Feature Card - Meal Plan") {
    HomeLifeFeatureCard(
        title: "Meal Plan",
        description: "Plan your family meals",
        icon: "🍽️",
        gradientColors: [.brandPrimary, .brandSecondary],
        action: {}
    )
    .frame(width: 160, height: 140)
    .padding()
    .background(Color(.systemGroupedBackground))
    .previewEnvironment(.authenticated)
}

#Preview("HomeLife Feature Card - Grocery List") {
    HomeLifeFeatureCard(
        title: "Grocery List",
        description: "Manage shopping lists",
        icon: "🛒",
        gradientColors: [.green, .mint],
        action: {}
    )
    .frame(width: 160, height: 140)
    .padding()
    .background(Color(.systemGroupedBackground))
    .previewEnvironment(.authenticated)
}

#Preview("HomeLife Feature Card - Tasks") {
    HomeLifeFeatureCard(
        title: "Tasks",
        description: "Assign shopping tasks",
        icon: "✅",
        gradientColors: [.orange, .yellow],
        action: {}
    )
    .frame(width: 160, height: 140)
    .padding()
    .background(Color(.systemGroupedBackground))
    .previewEnvironment(.authenticated)
}

#Preview("HomeLife Feature Card - Pantry") {
    HomeLifeFeatureCard(
        title: "Pantry",
        description: "Check what you have",
        icon: "📋",
        gradientColors: [.purple, .pink],
        action: {}
    )
    .frame(width: 160, height: 140)
    .padding()
    .background(Color(.systemGroupedBackground))
    .previewEnvironment(.authenticated)
}

#Preview("HomeLife Cards Grid") {
    LazyVGrid(columns: [
        GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
        GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
    ], spacing: DesignSystem.Spacing.lg) {
        HomeLifeFeatureCard(
            title: "Meal Plan",
            description: "Plan your family meals",
            icon: "🍽️",
            gradientColors: [.brandPrimary, .brandSecondary],
            action: {}
        )
        
        HomeLifeFeatureCard(
            title: "Grocery List",
            description: "Manage shopping lists",
            icon: "🛒",
            gradientColors: [.green, .mint],
            action: {}
        )
        
        HomeLifeFeatureCard(
            title: "Tasks",
            description: "Assign shopping tasks",
            icon: "✅",
            gradientColors: [.orange, .yellow],
            action: {}
        )
        
        HomeLifeFeatureCard(
            title: "Pantry",
            description: "Check what you have",
            icon: "📋",
            gradientColors: [.purple, .pink],
            action: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .previewEnvironment(.authenticated)
}

#Preview("HomeLife Cards Grid - Dark Mode") {
    LazyVGrid(columns: [
        GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
        GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
    ], spacing: DesignSystem.Spacing.lg) {
        HomeLifeFeatureCard(
            title: "Meal Plan",
            description: "Plan your family meals",
            icon: "🍽️",
            gradientColors: [.brandPrimary, .brandSecondary],
            action: {}
        )
        
        HomeLifeFeatureCard(
            title: "Grocery List",
            description: "Manage shopping lists",
            icon: "🛒",
            gradientColors: [.green, .mint],
            action: {}
        )
        
        HomeLifeFeatureCard(
            title: "Tasks",
            description: "Assign shopping tasks",
            icon: "✅",
            gradientColors: [.orange, .yellow],
            action: {}
        )
        
        HomeLifeFeatureCard(
            title: "Pantry",
            description: "Check what you have",
            icon: "📋",
            gradientColors: [.purple, .pink],
            action: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .previewEnvironment(.authenticated)
    .preferredColorScheme(.dark)
}