import SwiftUI

/// Grocery list view with tab interface for weekly and urgent items
struct GroceryListView: View {
    @StateObject private var viewModel = GroceryListViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                tabSelector
                
                // Content based on selected tab
                TabView(selection: $viewModel.selectedTab) {
                    weeklyGroceryListTab
                        .tag(GroceryListTab.weekly)
                    
                    urgentAdditionsTab
                        .tag(GroceryListTab.urgent)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(DesignSystem.Animation.smooth, value: viewModel.selectedTab)
            }
            .navigationTitle("Grocery List")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .overlay(alignment: .bottom) {
                if viewModel.hasItemsToOrder {
                    orderOnlineButton
                }
            }
            .sheet(isPresented: $viewModel.showAddUrgentItemSheet) {
                addUrgentItemSheet
            }
            .sheet(isPresented: $viewModel.showPlatformSelection) {
                platformSelectionSheet
            }
            .task {
                await viewModel.loadGroceryItems()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Grocery list view")
        .accessibilityHint("Manage weekly grocery lists and urgent additions")
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(GroceryListTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(DesignSystem.Animation.quick) {
                        viewModel.switchTab(to: tab)
                    }
                }) {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(tab.rawValue)
                                .labelMedium()
                            
                            // Badge for item count
                            if tab == .weekly && viewModel.weeklyItemCount > 0 {
                                badgeView(count: viewModel.weeklyItemCount, color: .blue)
                            } else if tab == .urgent && viewModel.urgentItemCount > 0 {
                                badgeView(count: viewModel.urgentItemCount, color: .red)
                            }
                        }
                        
                        // Selection indicator
                        Rectangle()
                            .fill(viewModel.selectedTab == tab ? Color.brandPrimary : Color.clear)
                            .frame(height: 2)
                            .animation(DesignSystem.Animation.quick, value: viewModel.selectedTab)
                    }
                }
                .foregroundColor(viewModel.selectedTab == tab ? .brandPrimary : .secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    private func badgeView(count: Int, color: Color) -> some View {
        Text("\(count)")
            .captionSmall()
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(color)
            )
            .frame(minWidth: 18)
    }
    
    // MARK: - Weekly Grocery List Tab
    
    private var weeklyGroceryListTab: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                if viewModel.weeklyGroceryItems.isEmpty {
                    weeklyEmptyState
                } else {
                    ForEach(viewModel.weeklyGroceryItems) { item in
                        groceryItemCard(item)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .padding(.bottom, viewModel.hasItemsToOrder ? 100 : 20)
        }
    }
    
    private var weeklyEmptyState: some View {
        EmptyStateView(
            icon: "calendar.badge.clock",
            title: "No Weekly Items",
            message: "Your weekly grocery list is empty. Items will appear here when you complete a pantry check from your meal plan.",
            style: .branded
        )
        .padding(.top, DesignSystem.Spacing.xxxl)
    }
    
    // MARK: - Urgent Additions Tab
    
    private var urgentAdditionsTab: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                if viewModel.urgentGroceryItems.isEmpty {
                    urgentEmptyState
                } else {
                    ForEach(viewModel.urgentGroceryItems) { item in
                        groceryItemCard(item)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .padding(.bottom, viewModel.hasItemsToOrder ? 100 : 20)
        }
        .overlay(alignment: .bottomTrailing) {
            // Add urgent item floating action button
            Button(action: {
                viewModel.showAddUrgentItemForm()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
            }
            .buttonStyle(FloatingActionButtonStyle())
            .padding(.trailing, DesignSystem.Spacing.lg)
            .padding(.bottom, viewModel.hasItemsToOrder ? 120 : 40)
        }
    }
    
    private var urgentEmptyState: some View {
        EmptyStateView(
            icon: "exclamationmark.triangle.fill",
            title: "No Urgent Items",
            message: "Add items that you need urgently or forgot to include in your weekly meal plan. Tap the + button to add urgent items.",
            actionTitle: "Add Urgent Item",
            action: {
                viewModel.showAddUrgentItemForm()
            },
            style: .branded
        )
        .padding(.top, DesignSystem.Spacing.xxxl)
    }
    
    // MARK: - Grocery Item Card
    
    private func groceryItemCard(_ item: GroceryItem) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Main item info
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                // Emoji and checkbox
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button(action: {
                        viewModel.toggleItemCompletion(item)
                    }) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(item.isCompleted ? .green : .brandPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(item.ingredient.emoji)
                        .font(.system(size: 24))
                }
                
                // Item details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text(item.ingredient.name)
                            .titleSmall()
                            .foregroundColor(.primary)
                            .strikethrough(item.isCompleted)
                        
                        Spacer()
                        
                        Text("\(item.ingredient.quantity) \(item.ingredient.unit)")
                            .labelMedium()
                            .foregroundColor(.secondary)
                    }
                    
                    // Attribution and meal info
                    VStack(alignment: .leading, spacing: 2) {
                        if let linkedMeal = item.linkedMeal {
                            Text("For: \(linkedMeal)")
                                .captionLarge()
                                .foregroundColor(.brandPrimary)
                        }
                        
                        Text("Added by: \(item.addedBy)")
                            .captionMedium()
                            .foregroundColor(.secondary)
                    }
                    
                    // Priority indicator for urgent items
                    if item.isUrgent {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                            
                            Text("Urgent")
                                .captionSmall()
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Notes if available
            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .captionLarge()
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.leading, 52) // Align with item name
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .opacity(item.isCompleted ? 0.6 : 1.0)
        )
        .lightShadow()
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Remove") {
                viewModel.removeItem(item)
            }
            .tint(.red)
        }
        .animation(DesignSystem.Animation.quick, value: item.isCompleted)
    }
    
    // MARK: - Order Online Button
    
    private var orderOnlineButton: some View {
        VStack(spacing: 0) {
            // Gradient overlay to blend with content
            LinearGradient(
                colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)
            
            // Button container
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Cost estimate
                HStack {
                    Text("Estimated total:")
                        .labelMedium()
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(viewModel.formattedEstimatedCost)
                        .titleSmall()
                        .foregroundColor(.primary)
                }
                
                // Order button
                Button(action: {
                    viewModel.showPlatformSelectionSheet()
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Order Online")
                            .font(DesignSystem.Typography.buttonLarge)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .cardPadding()
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Add Urgent Item Sheet
    
    private var addUrgentItemSheet: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Form fields
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Item name
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Item Name")
                            .labelMedium()
                            .foregroundColor(.primary)
                        
                        TextField("Enter item name", text: $viewModel.newUrgentItem.name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Quantity and unit
                    HStack(spacing: DesignSystem.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Quantity")
                                .labelMedium()
                                .foregroundColor(.primary)
                            
                            TextField("1", text: $viewModel.newUrgentItem.quantity)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Unit")
                                .labelMedium()
                                .foregroundColor(.primary)
                            
                            TextField("kg, cups, etc.", text: $viewModel.newUrgentItem.unit)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Notes (Optional)")
                            .labelMedium()
                            .foregroundColor(.primary)
                        
                        TextField("Add any notes", text: $viewModel.newUrgentItem.notes)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: DesignSystem.Spacing.md) {
                    Button("Add to Urgent List") {
                        viewModel.addUrgentItem()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!viewModel.newUrgentItem.isValid)
                    
                    Button("Cancel") {
                        viewModel.showAddUrgentItemSheet = false
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .screenPadding()
            .navigationTitle("Add Urgent Item")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
        }
    }
    
    // MARK: - Platform Selection Sheet
    
    private var platformSelectionSheet: some View {
        OrderPlatformSelectionView(
            groceryItems: viewModel.itemsForSelectedTab,
            onPlatformSelected: { platform in
                viewModel.selectPlatform(platform)
            }
        )
    }
}

// MARK: - Backward Compatibility

/// Alias for backward compatibility with existing navigation
typealias ShoppingView = GroceryListView

// MARK: - Preview

#Preview("Grocery List - Weekly Items") {
    GroceryListView()
        .previewEnvironment(.authenticated)
}

#Preview("Grocery List - Urgent Items") {
    GroceryListView()
        .onAppear {
            // Simulate switching to urgent tab
        }
        .previewEnvironment(.authenticated)
}

#Preview("Grocery List - Empty Weekly") {
    GroceryListView()
        .onAppear {
            // Simulate empty weekly list
        }
        .previewEnvironment(.authenticated)
}

#Preview("Grocery List - Empty Urgent") {
    GroceryListView()
        .onAppear {
            // Simulate empty urgent list
        }
        .previewEnvironment(.authenticated)
}

#Preview("Grocery List - Loading") {
    GroceryListView()
        .previewEnvironmentLoading()
}

#Preview("Grocery List - Dark Mode") {
    GroceryListView()
        .previewEnvironment(.authenticated)
        .preferredColorScheme(.dark)
}

#Preview("Grocery List - Large Text") {
    GroceryListView()
        .previewEnvironment(.authenticated)
        .environment(\.sizeCategory, .extraExtraExtraLarge)
}

#Preview("Grocery List - iPad") {
    GroceryListView()
        .previewEnvironment(.authenticated)
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
}

#Preview("Grocery List - High Contrast") {
    GroceryListView()
        .previewEnvironment(.authenticated)
}

// MARK: - Backward Compatibility Previews

#Preview("Shopping View") {
    ShoppingView()
        .previewEnvironment(.authenticated)
}

#Preview("Shopping View - Dark Mode") {
    ShoppingView()
        .previewEnvironment(.authenticated)
        .preferredColorScheme(.dark)
}

#Preview("Shopping View - Large Text") {
    ShoppingView()
        .previewEnvironment(.authenticated)
        .environment(\.sizeCategory, .extraExtraExtraLarge)
}