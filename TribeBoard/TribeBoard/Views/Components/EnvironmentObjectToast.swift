import SwiftUI

/// Non-intrusive toast notification for environment object issues
/// Provides subtle feedback about environment object problems without blocking the UI
struct EnvironmentObjectToast: View {
    let notification: EnvironmentObjectNotification
    let onDismiss: (() -> Void)?
    let onAction: ((EnvironmentRecoveryAction) -> Void)?
    
    @State private var isVisible = false
    @State private var offset: CGFloat = -100
    @State private var isExpanded = false
    
    init(
        notification: EnvironmentObjectNotification,
        onDismiss: (() -> Void)? = nil,
        onAction: ((EnvironmentRecoveryAction) -> Void)? = nil
    ) {
        self.notification = notification
        self.onDismiss = onDismiss
        self.onAction = onAction
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main toast content
            mainContent
            
            // Expanded actions (if expanded)
            if isExpanded {
                expandedActions
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(toastBackground)
        .padding(.horizontal, 16)
        .offset(y: offset)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            showToast()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(notification.accessibilityLabel)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityAction(named: "Dismiss") {
            dismiss()
        }
    }
    
    // MARK: - View Components
    
    private var mainContent: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: notification.icon)
                .font(.title3)
                .foregroundColor(notification.color)
            
            // Message content
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if !notification.message.isEmpty {
                    Text(notification.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 1)
                }
            }
            
            Spacer()
            
            // Action buttons
            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            // Primary action (if available)
            if let primaryAction = notification.primaryAction {
                Button(action: {
                    executeAction(primaryAction)
                }) {
                    Text(primaryAction.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.brandPrimary)
                }
            }
            
            // Expand/collapse button (if has secondary actions)
            if !notification.secondaryActions.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Dismiss button
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var expandedActions: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.horizontal, 16)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(notification.secondaryActions, id: \.self) { action in
                    Button(action: {
                        executeAction(action)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: action.icon)
                                .font(.caption2)
                            Text(action.title)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    private var toastBackground: some View {
        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
            .fill(Color(.systemBackground))
            .shadow(
                color: BrandStyle.standardShadow,
                radius: 8,
                x: 0,
                y: 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .stroke(notification.color.opacity(0.3), lineWidth: 1)
            )
    }
    
    // MARK: - Actions
    
    private func showToast() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isVisible = true
            offset = 0
        }
        
        // Auto-dismiss after duration (if not persistent)
        if !notification.isPersistent {
            DispatchQueue.main.asyncAfter(deadline: .now() + notification.duration) {
                dismiss()
            }
        }
        
        // Haptic feedback
        HapticManager.shared.lightImpact()
    }
    
    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
            offset = -100
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss?()
        }
    }
    
    private func executeAction(_ action: EnvironmentRecoveryAction) {
        onAction?(action)
        
        // Collapse if expanded
        if isExpanded {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = false
            }
        }
        
        // Auto-dismiss for certain actions
        if [.useDefaultState, .refreshEnvironment].contains(action) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }
}

/// Notification data for environment object issues
struct EnvironmentObjectNotification {
    let id: UUID
    let type: EnvironmentNotificationType
    let title: String
    let message: String
    let primaryAction: EnvironmentRecoveryAction?
    let secondaryActions: [EnvironmentRecoveryAction]
    let duration: TimeInterval
    let isPersistent: Bool
    
    init(
        id: UUID = UUID(),
        type: EnvironmentNotificationType,
        title: String,
        message: String = "",
        primaryAction: EnvironmentRecoveryAction? = nil,
        secondaryActions: [EnvironmentRecoveryAction] = [],
        duration: TimeInterval = 5.0,
        isPersistent: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryActions = secondaryActions
        self.duration = duration
        self.isPersistent = isPersistent
    }
    
    var icon: String {
        type.icon
    }
    
    var color: Color {
        type.color
    }
    
    var accessibilityLabel: String {
        "\(type.accessibilityLabel): \(title). \(message)"
    }
}

/// Types of environment object notifications
enum EnvironmentNotificationType {
    case missingEnvironment
    case fallbackActive
    case stateInconsistent
    case dependencyIssue
    case recoverySuccessful
    case recoveryFailed
    
    var icon: String {
        switch self {
        case .missingEnvironment:
            return "exclamationmark.triangle.fill"
        case .fallbackActive:
            return "gear.badge"
        case .stateInconsistent:
            return "exclamationmark.circle.fill"
        case .dependencyIssue:
            return "link.badge.plus"
        case .recoverySuccessful:
            return "checkmark.circle.fill"
        case .recoveryFailed:
            return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .missingEnvironment:
            return .orange
        case .fallbackActive:
            return .blue
        case .stateInconsistent:
            return .red
        case .dependencyIssue:
            return .purple
        case .recoverySuccessful:
            return .green
        case .recoveryFailed:
            return .red
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .missingEnvironment:
            return "Missing Environment Warning"
        case .fallbackActive:
            return "Fallback Active Information"
        case .stateInconsistent:
            return "State Issue Warning"
        case .dependencyIssue:
            return "Dependency Issue Warning"
        case .recoverySuccessful:
            return "Recovery Successful"
        case .recoveryFailed:
            return "Recovery Failed"
        }
    }
}

/// Manager for environment object toast notifications
@MainActor
class EnvironmentObjectToastManager: ObservableObject {
    static let shared = EnvironmentObjectToastManager()
    
    @Published var currentNotification: EnvironmentObjectNotification?
    
    private init() {}
    
    /// Show a notification for environment object issues
    func show(_ notification: EnvironmentObjectNotification) {
        currentNotification = notification
    }
    
    /// Dismiss the current notification
    func dismiss() {
        currentNotification = nil
    }
    
    // MARK: - Convenience Methods
    
    /// Show notification for missing environment object
    func showMissingEnvironment(type: String, viewName: String? = nil) {
        let title = "App State Missing"
        let message = viewName != nil ? "in \(viewName!)" : ""
        
        let notification = EnvironmentObjectNotification(
            type: .missingEnvironment,
            title: title,
            message: message,
            primaryAction: .useDefaultState,
            secondaryActions: [.refreshEnvironment, .reportIssue],
            duration: 6.0
        )
        
        show(notification)
    }
    
    /// Show notification for fallback being used
    func showFallbackActive(type: String) {
        let notification = EnvironmentObjectNotification(
            type: .fallbackActive,
            title: "Using Fallback State",
            message: "Some features may be limited",
            primaryAction: .refreshEnvironment,
            secondaryActions: [.checkDependencies],
            duration: 4.0
        )
        
        show(notification)
    }
    
    /// Show notification for state inconsistency
    func showStateInconsistent(details: String? = nil) {
        let message = details ?? "App state needs attention"
        
        let notification = EnvironmentObjectNotification(
            type: .stateInconsistent,
            title: "State Issue Detected",
            message: message,
            primaryAction: .refreshEnvironment,
            secondaryActions: [.resetNavigation, .useDefaultState, .reportIssue],
            duration: 7.0
        )
        
        show(notification)
    }
    
    /// Show notification for dependency issues
    func showDependencyIssue(missing: [String]) {
        let missingList = missing.joined(separator: ", ")
        
        let notification = EnvironmentObjectNotification(
            type: .dependencyIssue,
            title: "Dependency Issue",
            message: "Missing: \(missingList)",
            primaryAction: .checkDependencies,
            secondaryActions: [.useDefaultState, .reportIssue],
            duration: 6.0
        )
        
        show(notification)
    }
    
    /// Show notification for successful recovery
    func showRecoverySuccessful(action: EnvironmentRecoveryAction) {
        let notification = EnvironmentObjectNotification(
            type: .recoverySuccessful,
            title: "Issue Resolved",
            message: "\(action.title) completed successfully",
            duration: 3.0
        )
        
        show(notification)
    }
    
    /// Show notification for failed recovery
    func showRecoveryFailed(action: EnvironmentRecoveryAction, error: String? = nil) {
        let message = error ?? "\(action.title) was not successful"
        
        let notification = EnvironmentObjectNotification(
            type: .recoveryFailed,
            title: "Recovery Failed",
            message: message,
            primaryAction: .reportIssue,
            secondaryActions: [.useDefaultState],
            duration: 5.0
        )
        
        show(notification)
    }
    
    // MARK: - Batch Notifications
    
    /// Show a sequence of notifications for complex recovery flows
    func showRecoverySequence(
        initialAction: EnvironmentRecoveryAction,
        onComplete: @escaping (Bool) -> Void
    ) {
        // Step 1: Show starting notification
        let startNotification = EnvironmentObjectNotification(
            type: .fallbackActive,
            title: "Starting Recovery",
            message: "Attempting to fix environment issues...",
            duration: 2.0
        )
        show(startNotification)
        
        // Step 2: Simulate recovery process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            let progressNotification = EnvironmentObjectNotification(
                type: .fallbackActive,
                title: "Recovery in Progress",
                message: "Please wait while we fix the issue...",
                duration: 2.0
            )
            self.show(progressNotification)
        }
        
        // Step 3: Show result
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            let success = Bool.random() // Simulate success/failure
            
            if success {
                self.showRecoverySuccessful(action: initialAction)
                onComplete(true)
            } else {
                self.showRecoveryFailed(action: initialAction)
                onComplete(false)
            }
        }
    }
}

/// Toast container view modifier for environment object notifications
struct EnvironmentObjectToastViewModifier: ViewModifier {
    @StateObject private var toastManager = EnvironmentObjectToastManager.shared
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if let notification = toastManager.currentNotification {
                EnvironmentObjectToast(
                    notification: notification,
                    onDismiss: {
                        toastManager.dismiss()
                    },
                    onAction: { action in
                        handleRecoveryAction(action, for: notification)
                    }
                )
                .zIndex(1000)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private func handleRecoveryAction(_ action: EnvironmentRecoveryAction, for notification: EnvironmentObjectNotification) {
        // Log the action
        print("🔧 Environment Recovery Action: \(action.title)")
        
        // Simulate action execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Show result notification
            if Bool.random() { // Simulate success/failure
                toastManager.showRecoverySuccessful(action: action)
            } else {
                toastManager.showRecoveryFailed(action: action)
            }
        }
    }
}

extension View {
    /// Add environment object toast notifications to a view
    func withEnvironmentObjectToast() -> some View {
        modifier(EnvironmentObjectToastViewModifier())
    }
}

// MARK: - Preview

#Preview("Environment Object Toast") {
    VStack(spacing: 20) {
        Text("Environment Object Toast Demo")
            .font(.title)
            .padding()
        
        VStack(spacing: 12) {
            Button("Missing Environment") {
                EnvironmentObjectToastManager.shared.showMissingEnvironment(
                    type: "AppState",
                    viewName: "ScheduledRunsListView"
                )
            }
            .buttonStyle(.bordered)
            
            Button("Fallback Active") {
                EnvironmentObjectToastManager.shared.showFallbackActive(type: "AppState")
            }
            .buttonStyle(.bordered)
            
            Button("State Inconsistent") {
                EnvironmentObjectToastManager.shared.showStateInconsistent(
                    details: "Navigation path is corrupted"
                )
            }
            .buttonStyle(.bordered)
            
            Button("Dependency Issue") {
                EnvironmentObjectToastManager.shared.showDependencyIssue(
                    missing: ["AppState", "NavigationManager"]
                )
            }
            .buttonStyle(.bordered)
            
            Button("Recovery Sequence") {
                EnvironmentObjectToastManager.shared.showRecoverySequence(
                    initialAction: .refreshEnvironment
                ) { success in
                    print("Recovery completed: \(success)")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        
        Spacer()
    }
    .withEnvironmentObjectToast()
}

#Preview("Individual Toast") {
    EnvironmentObjectToast(
        notification: EnvironmentObjectNotification(
            type: .missingEnvironment,
            title: "App State Missing",
            message: "in ScheduledRunsListView",
            primaryAction: .useDefaultState,
            secondaryActions: [.refreshEnvironment, .reportIssue, .checkDependencies]
        ),
        onDismiss: {
            print("Toast dismissed")
        },
        onAction: { action in
            print("Action: \(action)")
        }
    )
    .padding()
}