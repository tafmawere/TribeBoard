import SwiftUI

/// Comprehensive showcase of micro-interactions and animations for the prototype
struct MicroInteractionsShowcase: View {
    @State private var buttonPressed = false
    @State private var toggleState = false
    @State private var sliderValue: Double = 0.5
    @State private var showSuccess = false
    @State private var showError = false
    @State private var isLoading = false
    @State private var cardExpanded = false
    @State private var heartLiked = false
    @State private var starRating = 0
    @State private var showModal = false
    @State private var pulseActive = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Button Interactions
                    buttonInteractionsSection
                    
                    // Toggle and Slider Interactions
                    controlInteractionsSection
                    
                    // Card Interactions
                    cardInteractionsSection
                    
                    // Feedback Animations
                    feedbackAnimationsSection
                    
                    // Loading States
                    loadingStatesSection
                    
                    // Success and Error States
                    statusAnimationsSection
                    
                    // Rating and Like Interactions
                    ratingInteractionsSection
                    
                    // Modal and Sheet Interactions
                    modalInteractionsSection
                }
                .padding()
            }
            .navigationTitle("Micro-Interactions")
            .navigationBarTitleDisplayMode(.large)
            .withToast()
        }
        .sheet(isPresented: $showModal) {
            modalContent
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("🎨 Animation Showcase")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.brandPrimary)
            
            Text("Explore production-quality animations and micro-interactions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(LinearGradient.brandGradientSubtle)
        )
    }
    
    private var buttonInteractionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Button Interactions", icon: "hand.tap")
            
            VStack(spacing: 12) {
                AnimatedPrimaryButton(
                    title: "Primary Action",
                    action: {
                        ToastManager.shared.success("Primary button tapped!")
                    },
                    icon: "star.fill"
                )
                
                AnimatedSecondaryButton(
                    title: "Secondary Action",
                    action: {
                        ToastManager.shared.info("Secondary button tapped!")
                    },
                    icon: "heart"
                )
                
                HStack(spacing: 12) {
                    AnimatedIconButton(
                        icon: "plus",
                        action: {
                            ToastManager.shared.success("Added!")
                        },
                        color: .green,
                        backgroundColor: Color.green.opacity(0.1)
                    )
                    
                    AnimatedIconButton(
                        icon: "minus",
                        action: {
                            ToastManager.shared.warning("Removed!")
                        },
                        color: .red,
                        backgroundColor: Color.red.opacity(0.1)
                    )
                    
                    AnimatedIconButton(
                        icon: "heart.fill",
                        action: {
                            heartLiked.toggle()
                            if heartLiked {
                                ToastManager.shared.success("Liked! ❤️")
                            } else {
                                ToastManager.shared.info("Unliked")
                            }
                        },
                        color: heartLiked ? .red : .gray,
                        backgroundColor: heartLiked ? Color.red.opacity(0.1) : Color.gray.opacity(0.1)
                    )
                    .celebrationAnimation(trigger: heartLiked)
                    
                    Spacer()
                }
            }
        }
    }
    
    private var controlInteractionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Control Interactions", icon: "slider.horizontal.3")
            
            VStack(spacing: 16) {
                AnimatedToggleButton(
                    isOn: $toggleState,
                    label: "Notifications"
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Volume: \(Int(sliderValue * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Slider(value: $sliderValue, in: 0...1)
                        .accentColor(.brandPrimary)
                        .onChange(of: sliderValue) { _, _ in
                            HapticManager.shared.lightImpact()
                        }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .fill(Color(.systemBackground))
                        .shadow(color: BrandStyle.standardShadow, radius: 4, x: 0, y: 2)
                )
            }
        }
    }
    
    private var cardInteractionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Card Interactions", icon: "rectangle.stack")
            
            VStack(spacing: 12) {
                AnimatedCardButton(
                    title: "Family Calendar",
                    subtitle: "View upcoming events and birthdays",
                    icon: "calendar",
                    action: {
                        ToastManager.shared.info("Opening calendar...")
                    }
                )
                
                // Expandable card
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: {
                        withAnimation(AnimationUtilities.smooth) {
                            cardExpanded.toggle()
                        }
                        HapticManager.shared.lightImpact()
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .foregroundColor(.brandPrimary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Expandable Card")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Tap to expand")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: cardExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(cardExpanded ? 180 : 0))
                                .animation(AnimationUtilities.smooth, value: cardExpanded)
                        }
                        .padding()
                    }
                    
                    if cardExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Additional Content")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("This content appears when the card is expanded. It demonstrates smooth expand/collapse animations with proper timing and easing.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .fill(Color(.systemBackground))
                        .shadow(color: BrandStyle.standardShadow, radius: 4, x: 0, y: 2)
                )
            }
        }
    }
    
    private var feedbackAnimationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Haptic Feedback", icon: "iphone.radiowaves.left.and.right")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                feedbackButton("Light", style: .light)
                feedbackButton("Medium", style: .medium)
                feedbackButton("Heavy", style: .heavy)
                feedbackButton("Success", style: .success)
                feedbackButton("Warning", style: .warning)
                feedbackButton("Error", style: .error)
            }
        }
    }
    
    private var loadingStatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Loading States", icon: "arrow.clockwise")
            
            VStack(spacing: 12) {
                AnimatedPrimaryButton(
                    title: isLoading ? "Loading..." : "Start Loading",
                    action: {
                        isLoading = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            isLoading = false
                            ToastManager.shared.success("Loading completed!")
                        }
                    },
                    isLoading: isLoading,
                    icon: isLoading ? nil : "play.fill"
                )
                
                if isLoading {
                    LoadingStateView(
                        message: "Processing your request...",
                        style: .card,
                        mockScenario: .dataSync
                    )
                    .transition(AnimationUtilities.fadeTransition)
                }
            }
        }
    }
    
    private var statusAnimationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Status Animations", icon: "checkmark.circle")
            
            HStack(spacing: 12) {
                AnimatedSecondaryButton(
                    title: "Success",
                    action: {
                        showSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            showSuccess = false
                        }
                    },
                    icon: "checkmark.circle"
                )
                
                AnimatedSecondaryButton(
                    title: "Error",
                    action: {
                        showError = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            showError = false
                        }
                    },
                    icon: "xmark.circle"
                )
            }
            
            if showSuccess {
                QuickSuccessAnimation(
                    isVisible: showSuccess,
                    message: "Operation completed successfully!"
                )
                .transition(AnimationUtilities.scaleTransition)
            }
            
            if showError {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("Something went wrong. Please try again.")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
                .shakeAnimation(trigger: showError)
                .transition(AnimationUtilities.scaleTransition)
            }
        }
    }
    
    private var ratingInteractionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Rating Interactions", icon: "star")
            
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("Rate this experience:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    ForEach(1...5, id: \.self) { index in
                        Button(action: {
                            starRating = index
                            HapticManager.shared.lightImpact()
                            ToastManager.shared.success("Rated \(index) star\(index == 1 ? "" : "s")!")
                        }) {
                            Image(systemName: index <= starRating ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundColor(index <= starRating ? .yellow : .gray)
                        }
                        .scaleEffect(index <= starRating ? 1.1 : 1.0)
                        .animation(AnimationUtilities.spring, value: starRating)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .fill(Color(.systemBackground))
                        .shadow(color: BrandStyle.standardShadow, radius: 4, x: 0, y: 2)
                )
            }
        }
    }
    
    private var modalInteractionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Modal Interactions", icon: "rectangle.stack.badge.plus")
            
            VStack(spacing: 12) {
                AnimatedCardButton(
                    title: "Show Modal",
                    subtitle: "Demonstrates modal presentation with animations",
                    icon: "plus.rectangle.on.rectangle",
                    action: {
                        showModal = true
                    }
                )
                
                AnimatedFloatingActionButton(
                    icon: "plus",
                    action: {
                        ToastManager.shared.info("Floating action button tapped!")
                    }
                )
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(.brandPrimary)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
    
    private func feedbackButton(_ title: String, style: HapticStyle) -> some View {
        Button(action: {
            style.trigger()
            ToastManager.shared.info("\(title) haptic feedback")
        }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                        .fill(Color.brandPrimary.opacity(0.1))
                )
        }
        .buttonPressAnimation(isPressed: false, hapticStyle: style)
    }
    
    private var modalContent: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("🎉 Modal Presentation")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("This modal demonstrates smooth presentation and dismissal animations with proper haptic feedback.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    AnimatedPrimaryButton(
                        title: "Success Action",
                        action: {
                            ToastManager.shared.success("Modal action completed!")
                            showModal = false
                        },
                        icon: "checkmark"
                    )
                    
                    AnimatedSecondaryButton(
                        title: "Cancel",
                        action: {
                            showModal = false
                        },
                        icon: "xmark"
                    )
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Modal Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showModal = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    MicroInteractionsShowcase()
}