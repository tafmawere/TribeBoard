import SwiftUI

/// Enhanced platform selection view for grocery ordering with animations and toast feedback
struct OrderPlatformSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var toastManager = ToastManager.shared
    @State private var selectedPlatform: GroceryPlatform?
    @State private var isSubmittingOrder = false
    @State private var animatingPlatform: UUID?
    
    let groceryItems: [GroceryItem]
    let onPlatformSelected: (GroceryPlatform) -> Void
    
    private let platforms = MealPlanDataProvider.mockGroceryPlatforms()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header section
                    headerSection
                    
                    // Platform cards
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(platforms) { platform in
                            platformCard(platform)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    // Order summary
                    orderSummarySection
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .navigationTitle("Choose Platform")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmittingOrder)
                }
            }
            .overlay {
                if isSubmittingOrder {
                    submissionOverlay
                }
            }
        }
        .withToast()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "cart.fill.badge.plus")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.brandPrimary)
            
            Text("Select Delivery Platform")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(.primary)
            
            Text("Choose your preferred grocery delivery service")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
    
    // MARK: - Platform Card
    
    private func platformCard(_ platform: GroceryPlatform) -> some View {
        Button(action: {
            selectPlatform(platform)
        }) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Platform header with logo and info
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Platform logo placeholder with brand styling
                    platformLogo(for: platform)
                    
                    // Platform details
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(platform.name)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text(platform.description)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.brandPrimary)
                        .scaleEffect(animatingPlatform == platform.id ? 1.2 : 1.0)
                        .animation(DesignSystem.Animation.spring, value: animatingPlatform)
                }
                
                Divider()
                    .padding(.horizontal, -DesignSystem.Spacing.lg)
                
                // Platform details grid
                HStack(spacing: DesignSystem.Spacing.lg) {
                    platformDetailItem(
                        icon: "clock.fill",
                        title: "Delivery Time",
                        value: platform.deliveryTime,
                        color: .green
                    )
                    
                    Spacer()
                    
                    platformDetailItem(
                        icon: "banknote.fill",
                        title: "Min Order",
                        value: platform.formattedMinimumOrder,
                        color: .blue
                    )
                    
                    Spacer()
                    
                    platformDetailItem(
                        icon: "truck.box.fill",
                        title: "Delivery Fee",
                        value: platform.formattedDeliveryFee,
                        color: .orange
                    )
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: animatingPlatform == platform.id ? 
                            Color.brandPrimary.opacity(0.3) : 
                            BrandStyle.standardShadow,
                        radius: animatingPlatform == platform.id ? 12 : 8,
                        x: 0,
                        y: animatingPlatform == platform.id ? 6 : 4
                    )
            )
            .scaleEffect(animatingPlatform == platform.id ? 1.02 : 1.0)
            .animation(DesignSystem.Animation.spring, value: animatingPlatform)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isSubmittingOrder)
    }
    
    // MARK: - Platform Logo
    
    private func platformLogo(for platform: GroceryPlatform) -> some View {
        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
            .fill(platformGradient(for: platform))
            .frame(width: 60, height: 60)
            .overlay(
                VStack(spacing: 2) {
                    Image(systemName: platformIcon(for: platform))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(platformInitials(for: platform))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
            )
            .shadow(
                color: platformColor(for: platform).opacity(0.3),
                radius: 4,
                x: 0,
                y: 2
            )
    }
    
    // MARK: - Platform Detail Item
    
    private func platformDetailItem(
        icon: String,
        title: String,
        value: String,
        color: Color
    ) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            
            Text(title)
                .font(DesignSystem.Typography.captionSmall)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(.primary)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Order Summary Section
    
    private var orderSummarySection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Order Summary")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text("Items")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(groceryItems.count) items")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Estimated Total")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(estimatedTotal)
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(.brandPrimary)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(LinearGradient.brandGradientSubtle)
        )
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
    
    // MARK: - Submission Overlay
    
    private var submissionOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Loading animation
                ZStack {
                    Circle()
                        .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.brandPrimary, lineWidth: 4)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(
                            Animation.linear(duration: 1.0).repeatForever(autoreverses: false),
                            value: isSubmittingOrder
                        )
                }
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Submitting Order")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(.primary)
                    
                    if let platform = selectedPlatform {
                        Text("Sending your grocery list to \(platform.name)")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(DesignSystem.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: BrandStyle.standardShadow,
                        radius: 16,
                        x: 0,
                        y: 8
                    )
            )
            .padding(.horizontal, DesignSystem.Spacing.xl)
        }
    }
    
    // MARK: - Computed Properties
    
    private var estimatedTotal: String {
        let basePrice = 15.0
        let total = Double(groceryItems.count) * basePrice
        return String(format: "R%.0f", total)
    }
    
    // MARK: - Actions
    
    private func selectPlatform(_ platform: GroceryPlatform) {
        // Animate selection
        animatingPlatform = platform.id
        selectedPlatform = platform
        
        // Haptic feedback
        HapticManager.shared.lightImpact()
        
        // Start submission process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            submitOrder(to: platform)
        }
    }
    
    private func submitOrder(to platform: GroceryPlatform) {
        isSubmittingOrder = true
        
        // Simulate order submission with realistic delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            // Success feedback
            HapticManager.shared.success()
            
            // Show success toast
            toastManager.success("🛒 Order submitted to \(platform.name)! Estimated delivery: \(platform.deliveryTime)")
            
            // Call completion handler
            onPlatformSelected(platform)
            
            // Reset state and dismiss
            isSubmittingOrder = false
            animatingPlatform = nil
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }
    
    // MARK: - Platform Styling Helpers
    
    private func platformColor(for platform: GroceryPlatform) -> Color {
        switch platform.name {
        case "Woolworths Dash":
            return Color.green
        case "Checkers Sixty60":
            return Color.blue
        case "Pick n Pay asap!":
            return Color.orange
        default:
            return Color.brandPrimary
        }
    }
    
    private func platformGradient(for platform: GroceryPlatform) -> LinearGradient {
        let color = platformColor(for: platform)
        return LinearGradient(
            gradient: Gradient(colors: [color, color.opacity(0.8)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func platformIcon(for platform: GroceryPlatform) -> String {
        switch platform.name {
        case "Woolworths Dash":
            return "leaf.fill"
        case "Checkers Sixty60":
            return "clock.fill"
        case "Pick n Pay asap!":
            return "bolt.fill"
        default:
            return "cart.fill"
        }
    }
    
    private func platformInitials(for platform: GroceryPlatform) -> String {
        switch platform.name {
        case "Woolworths Dash":
            return "WD"
        case "Checkers Sixty60":
            return "C60"
        case "Pick n Pay asap!":
            return "PnP"
        default:
            return "GP"
        }
    }
}

// MARK: - Preview

#Preview("Order Platform Selection") {
    OrderPlatformSelectionView(
        groceryItems: MealPlanDataProvider.mockGroceryItems(),
        onPlatformSelected: { platform in
            print("Selected platform: \(platform.name)")
        }
    )
    .previewEnvironment(.authenticated)
}

#Preview("Order Platform Selection - Few Items") {
    OrderPlatformSelectionView(
        groceryItems: Array(MealPlanDataProvider.mockGroceryItems().prefix(3)),
        onPlatformSelected: { platform in
            print("Selected platform: \(platform.name)")
        }
    )
    .previewEnvironment(.authenticated)
}

#Preview("Order Platform Selection - Many Items") {
    OrderPlatformSelectionView(
        groceryItems: Array(MealPlanDataProvider.mockGroceryItems().prefix(15)),
        onPlatformSelected: { platform in
            print("Selected platform: \(platform.name)")
        }
    )
    .previewEnvironment(.authenticated)
}

#Preview("Order Platform Selection - Single Item") {
    OrderPlatformSelectionView(
        groceryItems: Array(MealPlanDataProvider.mockGroceryItems().prefix(1)),
        onPlatformSelected: { platform in
            print("Selected platform: \(platform.name)")
        }
    )
    .previewEnvironment(.authenticated)
}

#Preview("Order Platform Selection - Dark Mode") {
    OrderPlatformSelectionView(
        groceryItems: MealPlanDataProvider.mockGroceryItems(),
        onPlatformSelected: { platform in
            print("Selected platform: \(platform.name)")
        }
    )
    .previewEnvironment(.authenticated)
    .preferredColorScheme(.dark)
}

#Preview("Order Platform Selection - Large Text") {
    OrderPlatformSelectionView(
        groceryItems: MealPlanDataProvider.mockGroceryItems(),
        onPlatformSelected: { platform in
            print("Selected platform: \(platform.name)")
        }
    )
    .previewEnvironment(.authenticated)
    .environment(\.sizeCategory, .extraExtraExtraLarge)
}

#Preview("Order Platform Selection - iPad") {
    OrderPlatformSelectionView(
        groceryItems: MealPlanDataProvider.mockGroceryItems(),
        onPlatformSelected: { platform in
            print("Selected platform: \(platform.name)")
        }
    )
    .previewEnvironment(.authenticated)
    .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
}

#Preview("Order Platform Selection - High Contrast") {
    OrderPlatformSelectionView(
        groceryItems: MealPlanDataProvider.mockGroceryItems(),
        onPlatformSelected: { platform in
            print("Selected platform: \(platform.name)")
        }
    )
    .previewEnvironment(.authenticated)
}