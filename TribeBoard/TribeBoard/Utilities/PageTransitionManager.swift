import SwiftUI

/// Page transition manager for coordinating smooth navigation animations
@MainActor
class PageTransitionManager: ObservableObject {
    static let shared = PageTransitionManager()
    
    @Published var isTransitioning = false
    @Published var transitionDirection: TransitionDirection = .forward
    
    private init() {}
    
    enum TransitionDirection {
        case forward
        case backward
        case modal
        case dismiss
    }
    
    /// Perform a page transition with animation and haptic feedback
    func performTransition(
        direction: TransitionDirection = .forward,
        animation: Animation = AnimationUtilities.smooth,
        hapticStyle: HapticStyle = .medium,
        action: @escaping () -> Void
    ) {
        // Set transition state
        transitionDirection = direction
        isTransitioning = true
        
        // Trigger haptic feedback
        hapticStyle.trigger()
        
        // Perform the transition
        withAnimation(animation) {
            action()
        }
        
        // Reset transition state after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + animation.duration) {
            self.isTransitioning = false
        }
    }
    
    /// Navigate forward with standard animation
    func navigateForward(action: @escaping () -> Void) {
        performTransition(
            direction: .forward,
            animation: AnimationUtilities.smooth,
            hapticStyle: .navigation,
            action: action
        )
    }
    
    /// Navigate backward with standard animation
    func navigateBackward(action: @escaping () -> Void) {
        performTransition(
            direction: .backward,
            animation: AnimationUtilities.smooth,
            hapticStyle: .navigation,
            action: action
        )
    }
    
    /// Present modal with scale animation
    func presentModal(action: @escaping () -> Void) {
        performTransition(
            direction: .modal,
            animation: AnimationUtilities.spring,
            hapticStyle: .medium,
            action: action
        )
    }
    
    /// Dismiss modal with scale animation
    func dismissModal(action: @escaping () -> Void) {
        performTransition(
            direction: .dismiss,
            animation: AnimationUtilities.smooth,
            hapticStyle: .light,
            action: action
        )
    }
    
    /// Get appropriate transition for current direction
    func getTransition() -> AnyTransition {
        switch transitionDirection {
        case .forward:
            return AnimationUtilities.slideTransition
        case .backward:
            return AnyTransition.asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .modal:
            return AnimationUtilities.scaleTransition
        case .dismiss:
            return AnimationUtilities.fadeTransition
        }
    }
}

/// View modifier for page transitions
struct PageTransitionModifier: ViewModifier {
    @StateObject private var transitionManager = PageTransitionManager.shared
    let customTransition: AnyTransition?
    
    init(customTransition: AnyTransition? = nil) {
        self.customTransition = customTransition
    }
    
    func body(content: Content) -> some View {
        content
            .transition(customTransition ?? transitionManager.getTransition())
            .opacity(transitionManager.isTransitioning ? 0.8 : 1.0)
            .animation(AnimationUtilities.smooth, value: transitionManager.isTransitioning)
    }
}

/// Enhanced navigation coordinator for app flows
@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var navigationStack: [AppFlow] = []
    @Published var isAnimating = false
    
    private let transitionManager = PageTransitionManager.shared
    
    /// Navigate to a new flow
    func navigate(to flow: AppFlow, animated: Bool = true) {
        if animated {
            transitionManager.navigateForward {
                self.navigationStack.append(flow)
            }
        } else {
            navigationStack.append(flow)
        }
    }
    
    /// Go back to previous flow
    func goBack(animated: Bool = true) {
        guard !navigationStack.isEmpty else { return }
        
        if animated {
            transitionManager.navigateBackward {
                _ = self.navigationStack.popLast()
            }
        } else {
            _ = navigationStack.popLast()
        }
    }
    
    /// Reset to root flow
    func resetToRoot(animated: Bool = true) {
        if animated {
            transitionManager.navigateBackward {
                self.navigationStack.removeAll()
            }
        } else {
            navigationStack.removeAll()
        }
    }
    
    /// Present modal flow
    func presentModal(_ flow: AppFlow) {
        transitionManager.presentModal {
            self.navigationStack.append(flow)
        }
    }
    
    /// Dismiss current modal
    func dismissModal() {
        guard !navigationStack.isEmpty else { return }
        
        transitionManager.dismissModal {
            _ = self.navigationStack.popLast()
        }
    }
    
    /// Get current flow
    var currentFlow: AppFlow? {
        return navigationStack.last
    }
    
    /// Check if can go back
    var canGoBack: Bool {
        return !navigationStack.isEmpty
    }
}

// MARK: - View Extensions

extension View {
    /// Apply page transition animation
    func pageTransition(customTransition: AnyTransition? = nil) -> some View {
        modifier(PageTransitionModifier(customTransition: customTransition))
    }
    
    /// Apply slide in animation for list items
    func listItemTransition(index: Int, isVisible: Bool = true) -> some View {
        self
            .slideInAnimation(index: index, isVisible: isVisible)
            .onAppear {
                HapticManager.shared.lightImpact()
            }
    }
    
    /// Apply success celebration animation
    func successTransition(trigger: Bool) -> some View {
        self
            .celebrationAnimation(trigger: trigger)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    ToastManager.shared.showRandomSuccessToast()
                }
            }
    }
    
    /// Apply error shake animation
    func errorTransition(trigger: Bool) -> some View {
        self
            .shakeAnimation(trigger: trigger)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    ToastManager.shared.showRandomErrorToast()
                }
            }
    }
}

// MARK: - Animation Duration Extension

extension Animation {
    /// Get the duration of an animation (approximation)
    var duration: TimeInterval {
        // Since we can't easily extract duration from SwiftUI Animation,
        // we'll return reasonable defaults based on animation type
        return 0.3 // Default duration for all animations
    }
}

// MARK: - Preview

#Preview("Page Transitions") {
    struct PageTransitionDemo: View {
        @State private var currentPage = 0
        @State private var showModal = false
        @StateObject private var coordinator = NavigationCoordinator()
        
        let pages = ["Page 1", "Page 2", "Page 3"]
        
        var body: some View {
            VStack(spacing: 30) {
                Text("Page Transition Demo")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Current page display
                ZStack {
                    ForEach(0..<pages.count, id: \.self) { index in
                        if index == currentPage {
                            VStack(spacing: 20) {
                                Text(pages[index])
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.brandPrimary)
                                
                                Text("This is \(pages[index].lowercased()) content")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: 200)
                            .background(
                                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                                    .fill(LinearGradient.brandGradientSubtle)
                            )
                            .pageTransition()
                        }
                    }
                }
                
                // Navigation controls
                HStack(spacing: 20) {
                    AnimatedSecondaryButton(
                        title: "Previous",
                        action: {
                            PageTransitionManager.shared.navigateBackward {
                                if currentPage > 0 {
                                    currentPage -= 1
                                }
                            }
                        },
                        isEnabled: currentPage > 0,
                        icon: "chevron.left"
                    )
                    
                    AnimatedPrimaryButton(
                        title: "Next",
                        action: {
                            PageTransitionManager.shared.navigateForward {
                                if currentPage < pages.count - 1 {
                                    currentPage += 1
                                }
                            }
                        },
                        isEnabled: currentPage < pages.count - 1,
                        icon: "chevron.right"
                    )
                }
                
                // Modal demo
                AnimatedCardButton(
                    title: "Show Modal",
                    subtitle: "Demonstrates modal transition",
                    icon: "rectangle.stack.badge.plus",
                    action: {
                        PageTransitionManager.shared.presentModal {
                            showModal = true
                        }
                    }
                )
                
                Spacer()
            }
            .padding()
            .sheet(isPresented: $showModal) {
                VStack(spacing: 20) {
                    Text("Modal View")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("This is a modal presentation with smooth transitions")
                        .multilineTextAlignment(.center)
                    
                    AnimatedSecondaryButton(
                        title: "Dismiss",
                        action: {
                            PageTransitionManager.shared.dismissModal {
                                showModal = false
                            }
                        },
                        icon: "xmark"
                    )
                }
                .padding()
                .presentationDetents([.medium])
            }
        }
    }
    
    return PageTransitionDemo()
}