import SwiftUI

/// Comprehensive showcase of the TribeBoard brand design system
struct BrandShowcaseView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Colors & Gradients
                colorsTab
                    .tabItem {
                        Image(systemName: "paintpalette")
                        Text("Colors")
                    }
                    .tag(0)
                
                // Typography
                typographyTab
                    .tabItem {
                        Image(systemName: "textformat")
                        Text("Typography")
                    }
                    .tag(1)
                
                // Components
                componentsTab
                    .tabItem {
                        Image(systemName: "square.stack.3d.up")
                        Text("Components")
                    }
                    .tag(2)
                
                // Spacing & Layout
                spacingTab
                    .tabItem {
                        Image(systemName: "ruler")
                        Text("Spacing")
                    }
                    .tag(3)
                
                // Animations
                animationsTab
                    .tabItem {
                        Image(systemName: "wand.and.stars")
                        Text("Animations")
                    }
                    .tag(4)
            }
            .navigationTitle("Brand Showcase")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Colors Tab
    
    private var colorsTab: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Brand Colors Section
                brandColorsSection
                
                // Gradients Section
                gradientsSection
                
                // Semantic Colors Section
                semanticColorsSection
                
                // Accessibility Colors Section
                accessibilityColorsSection
            }
            .screenPadding()
        }
    }
    
    private var brandColorsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Brand Colors")
                .headlineMedium()
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.lg) {
                colorCard(
                    color: .brandPrimary,
                    name: "Brand Primary",
                    description: "Main brand color for primary actions and emphasis"
                )
                
                colorCard(
                    color: .brandSecondary,
                    name: "Brand Secondary",
                    description: "Secondary brand color for accents and highlights"
                )
                
                colorCard(
                    color: .brandAccent,
                    name: "Brand Accent",
                    description: "Interactive elements and call-to-action buttons"
                )
                
                colorCard(
                    color: .brandText,
                    name: "Brand Text",
                    description: "Text color for brand backgrounds"
                )
            }
        }
    }
    
    private var gradientsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Brand Gradients")
                .headlineMedium()
                .foregroundColor(.primary)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                gradientCard(
                    gradient: LinearGradient.brandGradient,
                    name: "Primary Gradient",
                    description: "Main brand gradient for buttons and highlights"
                )
                
                gradientCard(
                    gradient: LinearGradient.brandGradientSubtle,
                    name: "Subtle Gradient",
                    description: "Subtle background gradient for sections"
                )
                
                gradientCard(
                    gradient: LinearGradient.brandGradientAccessible,
                    name: "Accessible Gradient",
                    description: "High contrast gradient for accessibility"
                )
            }
        }
    }
    
    private var semanticColorsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Semantic Colors")
                .headlineMedium()
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.lg) {
                colorCard(
                    color: .red,
                    name: "Error",
                    description: "Error states and destructive actions"
                )
                
                colorCard(
                    color: .orange,
                    name: "Warning",
                    description: "Warning states and caution messages"
                )
                
                colorCard(
                    color: .green,
                    name: "Success",
                    description: "Success states and positive feedback"
                )
                
                colorCard(
                    color: .blue,
                    name: "Info",
                    description: "Informational messages and neutral actions"
                )
            }
        }
    }
    
    private var accessibilityColorsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Accessibility Colors")
                .headlineMedium()
                .foregroundColor(.primary)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.lg) {
                    colorCard(
                        color: .brandPrimaryAccessible,
                        name: "Primary Accessible",
                        description: "High contrast primary color"
                    )
                    
                    colorCard(
                        color: .brandSecondaryAccessible,
                        name: "Secondary Accessible",
                        description: "High contrast secondary color"
                    )
                }
                
                Text("These colors automatically adapt based on accessibility settings")
                    .captionLarge()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Typography Tab
    
    private var typographyTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                // Display Fonts
                typographySection(
                    title: "Display Fonts",
                    samples: [
                        ("Display Large", DesignSystem.Typography.displayLarge),
                        ("Display Medium", DesignSystem.Typography.displayMedium),
                        ("Display Small", DesignSystem.Typography.displaySmall)
                    ]
                )
                
                // Headlines
                typographySection(
                    title: "Headlines",
                    samples: [
                        ("Headline Large", DesignSystem.Typography.headlineLarge),
                        ("Headline Medium", DesignSystem.Typography.headlineMedium),
                        ("Headline Small", DesignSystem.Typography.headlineSmall)
                    ]
                )
                
                // Titles
                typographySection(
                    title: "Titles",
                    samples: [
                        ("Title Large", DesignSystem.Typography.titleLarge),
                        ("Title Medium", DesignSystem.Typography.titleMedium),
                        ("Title Small", DesignSystem.Typography.titleSmall)
                    ]
                )
                
                // Body Text
                typographySection(
                    title: "Body Text",
                    samples: [
                        ("Body Large", DesignSystem.Typography.bodyLarge),
                        ("Body Medium", DesignSystem.Typography.bodyMedium),
                        ("Body Small", DesignSystem.Typography.bodySmall)
                    ]
                )
                
                // Labels & Captions
                typographySection(
                    title: "Labels & Captions",
                    samples: [
                        ("Label Large", DesignSystem.Typography.labelLarge),
                        ("Label Medium", DesignSystem.Typography.labelMedium),
                        ("Caption Large", DesignSystem.Typography.captionLarge),
                        ("Caption Medium", DesignSystem.Typography.captionMedium)
                    ]
                )
            }
            .screenPadding()
        }
    }
    
    // MARK: - Components Tab
    
    private var componentsTab: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Buttons Section
                buttonsSection
                
                // Cards Section
                cardsSection
                
                // Loading States Section
                loadingStatesSection
                
                // Empty States Section
                emptyStatesSection
            }
            .screenPadding()
        }
    }
    
    private var buttonsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Buttons")
                .headlineMedium()
                .foregroundColor(.primary)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                Button("Primary Button") {}
                    .buttonStyle(PrimaryButtonStyle())
                
                Button("Secondary Button") {}
                    .buttonStyle(SecondaryButtonStyle())
                
                Button("Tertiary Button") {}
                    .buttonStyle(TertiaryButtonStyle())
                
                Button("Destructive Button") {}
                    .buttonStyle(DestructiveButtonStyle())
                
                HStack(spacing: DesignSystem.Spacing.lg) {
                    Button(action: {}) {
                        Image(systemName: "heart.fill")
                    }
                    .buttonStyle(IconButtonStyle())
                    
                    Button(action: {}) {
                        Image(systemName: "star.fill")
                    }
                    .buttonStyle(IconButtonStyle(backgroundColor: Color.yellow.opacity(0.1)))
                    
                    Button(action: {}) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(FloatingActionButtonStyle())
                }
            }
        }
    }
    
    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Cards & Containers")
                .headlineMedium()
                .foregroundColor(.primary)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                // Standard Card
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Standard Card")
                        .titleMedium()
                        .foregroundColor(.primary)
                    
                    Text("This is a standard card with consistent padding, corner radius, and shadow.")
                        .bodyMedium()
                        .foregroundColor(.secondary)
                }
                .cardPadding()
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .fill(Color(.systemBackground))
                        .lightShadow()
                )
                
                // Branded Card
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Branded Card")
                        .titleMedium()
                        .foregroundColor(.white)
                    
                    Text("This card uses the brand gradient background with white text.")
                        .bodyMedium()
                        .foregroundColor(.white.opacity(0.9))
                }
                .cardPadding()
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .fill(LinearGradient.brandGradient)
                        .brandShadow()
                )
            }
        }
    }
    
    private var loadingStatesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Loading States")
                .headlineMedium()
                .foregroundColor(.primary)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                LoadingStateView(
                    message: "Loading family data...",
                    style: .card,
                    mockScenario: .dataSync
                )
                
                BrandedSkeletonView(rows: 2, showAvatar: true, style: .card)
            }
        }
    }
    
    private var emptyStatesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Empty States")
                .headlineMedium()
                .foregroundColor(.primary)
            
            EmptyStateView(
                icon: "person.3.fill",
                title: "No Family Members",
                message: "Your family is just getting started! Invite members to join.",
                actionTitle: "Invite Members",
                action: {},
                style: .branded
            )
            .frame(height: 300)
        }
    }
    
    // MARK: - Spacing Tab
    
    private var spacingTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                // Spacing Scale
                spacingScaleSection
                
                // Layout Examples
                layoutExamplesSection
            }
            .screenPadding()
        }
    }
    
    private var spacingScaleSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Spacing Scale")
                .headlineMedium()
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                spacingItem(name: "XS", value: DesignSystem.Spacing.xs)
                spacingItem(name: "SM", value: DesignSystem.Spacing.sm)
                spacingItem(name: "MD", value: DesignSystem.Spacing.md)
                spacingItem(name: "LG", value: DesignSystem.Spacing.lg)
                spacingItem(name: "XL", value: DesignSystem.Spacing.xl)
                spacingItem(name: "XXL", value: DesignSystem.Spacing.xxl)
                spacingItem(name: "XXXL", value: DesignSystem.Spacing.xxxl)
                spacingItem(name: "Huge", value: DesignSystem.Spacing.huge)
                spacingItem(name: "Massive", value: DesignSystem.Spacing.massive)
                spacingItem(name: "Gigantic", value: DesignSystem.Spacing.gigantic)
            }
        }
    }
    
    private var layoutExamplesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Layout Examples")
                .headlineMedium()
                .foregroundColor(.primary)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                // Content Padding Example
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Content Padding")
                        .labelLarge()
                        .foregroundColor(.secondary)
                    
                    Text("This content uses standard content padding")
                        .bodyMedium()
                        .foregroundColor(.primary)
                }
                .contentPadding()
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                        .fill(Color.brandPrimary.opacity(0.1))
                )
                
                // Card Padding Example
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Card Padding")
                        .labelLarge()
                        .foregroundColor(.secondary)
                    
                    Text("This content uses card padding with background")
                        .bodyMedium()
                        .foregroundColor(.primary)
                }
                .cardPadding()
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .fill(Color(.systemBackground))
                        .lightShadow()
                )
            }
        }
    }
    
    // MARK: - Animations Tab
    
    private var animationsTab: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                animationExamplesSection
            }
            .screenPadding()
        }
    }
    
    private var animationExamplesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Animation Examples")
                .headlineMedium()
                .foregroundColor(.primary)
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Button Animations
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Button Animations")
                        .titleMedium()
                        .foregroundColor(.primary)
                    
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        Button("Press Me") {}
                            .buttonStyle(PrimaryButtonStyle())
                        
                        Button("Tap Here") {}
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                
                // Loading Animations
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Loading Animations")
                        .titleMedium()
                        .foregroundColor(.primary)
                    
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        LoadingStateView(style: .pulse)
                        LoadingStateView(style: .shimmer)
                        LoadingStateView(style: .minimal)
                    }
                }
                
                // Transition Examples
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Page Transitions")
                        .titleMedium()
                        .foregroundColor(.primary)
                    
                    Text("All page transitions use consistent timing and easing curves from the design system.")
                        .bodyMedium()
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func colorCard(color: Color, name: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Rectangle()
                .fill(color)
                .frame(height: 80)
                .cornerRadius(BrandStyle.cornerRadiusSmall)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(name)
                    .labelLarge()
                    .foregroundColor(.primary)
                
                Text(description)
                    .captionMedium()
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .contentPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    private func gradientCard(gradient: LinearGradient, name: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Rectangle()
                .fill(gradient)
                .frame(height: 60)
                .cornerRadius(BrandStyle.cornerRadiusSmall)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(name)
                    .labelLarge()
                    .foregroundColor(.primary)
                
                Text(description)
                    .captionMedium()
                    .foregroundColor(.secondary)
            }
        }
        .contentPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    private func typographySection(title: String, samples: [(String, Font)]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text(title)
                .headlineMedium()
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(sample.0)
                            .font(sample.1)
                            .foregroundColor(.primary)
                        
                        Text("Sample text using \(sample.0)")
                            .captionMedium()
                            .foregroundColor(.secondary)
                    }
                    .contentPadding()
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                            .fill(Color(.systemGray6))
                    )
                }
            }
        }
    }
    
    private func spacingItem(name: String, value: CGFloat) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Rectangle()
                .fill(Color.brandPrimary)
                .frame(width: value, height: 20)
            
            Text("\(name) - \(Int(value))pt")
                .labelMedium()
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Brand Showcase") {
    BrandShowcaseView()
}