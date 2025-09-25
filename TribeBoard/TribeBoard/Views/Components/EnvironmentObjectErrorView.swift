import SwiftUI

/// Specialized error view for environment object issues
/// Provides user-friendly error messages and recovery actions for environment object problems
struct EnvironmentObjectErrorView: View {
    let error: EnvironmentObjectError
    let context: EnvironmentErrorContext
    let onRecoveryAction: ((EnvironmentRecoveryAction) -> Void)?
    let onDismiss: (() -> Void)?
    
    @State private var isRecovering = false
    @State private var recoveryResult: EnvironmentRecoveryResult?
    
    init(
        error: EnvironmentObjectError,
        context: EnvironmentErrorContext = .default,
        onRecoveryAction: ((EnvironmentRecoveryAction) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.context = context
        self.onRecoveryAction = onRecoveryAction
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Error icon and type
            errorHeader
            
            // Error content
            errorContent
            
            // Recovery result (if available)
            if let result = recoveryResult {
                recoveryResultView(result)
            }
            
            // Recovery actions
            recoveryActions
        }
        .padding(24)
        .background(errorBackground)
        .padding(.horizontal, 20)
    }
    
    // MARK: - View Components
    
    private var errorHeader: some View {
        HStack {
            Image(systemName: error.icon)
                .font(.system(size: 32))
                .foregroundColor(error.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("ENVIRONMENT ISSUE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(error.color)
                
                Text(error.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var errorContent: some View {
        VStack(spacing: 12) {
            Text(error.userFriendlyTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(error.userFriendlyMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            
            // Technical details (collapsible in debug mode)
            #if DEBUG
            if context.showTechnicalDetails {
                technicalDetailsView
            }
            #endif
        }
    }
    
    #if DEBUG
    private var technicalDetailsView: some View {
        DisclosureGroup("Technical Details") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Error: \(error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let recovery = error.recoverySuggestion {
                    Text("Recovery: \(recovery)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Context: \(context.viewName ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    #endif
    
    private var recoveryActions: some View {
        VStack(spacing: 12) {
            ForEach(error.availableRecoveryActions, id: \.self) { action in
                EnvironmentRecoveryActionButton(
                    action: action,
                    isLoading: isRecovering,
                    onTap: {
                        executeRecoveryAction(action)
                    }
                )
            }
            
            // Dismiss button
            if let onDismiss = onDismiss {
                Button("Dismiss", action: onDismiss)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var errorBackground: some View {
        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
            .fill(Color(.systemBackground))
            .shadow(
                color: BrandStyle.standardShadow,
                radius: BrandStyle.shadowRadius,
                x: BrandStyle.shadowOffset.width,
                y: BrandStyle.shadowOffset.height
            )
    }
    
    // MARK: - Recovery Actions
    
    private func executeRecoveryAction(_ action: EnvironmentRecoveryAction) {
        isRecovering = true
        recoveryResult = nil
        
        // Simulate recovery action execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let result = performRecoveryAction(action)
            recoveryResult = result
            isRecovering = false
            
            // Notify parent about the recovery action
            onRecoveryAction?(action)
            
            // Auto-dismiss on successful recovery for certain actions
            if result.isSuccessful && [.refreshEnvironment, .useDefaultState, .restartView].contains(action) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onDismiss?()
                }
            }
        }
    }
    
    private func performRecoveryAction(_ action: EnvironmentRecoveryAction) -> EnvironmentRecoveryResult {
        switch action {
        case .refreshEnvironment:
            return EnvironmentRecoveryResult(
                action: action,
                isSuccessful: true,
                message: "Environment refreshed successfully",
                nextRecommendedAction: nil
            )
        case .useDefaultState:
            return EnvironmentRecoveryResult(
                action: action,
                isSuccessful: true,
                message: "Using default state as fallback",
                nextRecommendedAction: nil
            )
        case .restartView:
            return EnvironmentRecoveryResult(
                action: action,
                isSuccessful: true,
                message: "View restarted with fresh environment",
                nextRecommendedAction: nil
            )
        case .reportIssue:
            return EnvironmentRecoveryResult(
                action: action,
                isSuccessful: true,
                message: "Issue reported to development team",
                nextRecommendedAction: .useDefaultState
            )
        case .checkDependencies:
            return EnvironmentRecoveryResult(
                action: action,
                isSuccessful: false,
                message: "Some dependencies are still missing",
                nextRecommendedAction: .useDefaultState
            )
        case .resetNavigation:
            return EnvironmentRecoveryResult(
                action: action,
                isSuccessful: true,
                message: "Navigation state reset successfully",
                nextRecommendedAction: nil
            )
        }
    }
    
    private func recoveryResultView(_ result: EnvironmentRecoveryResult) -> some View {
        HStack {
            Image(systemName: result.isSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.isSuccessful ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let nextAction = result.nextRecommendedAction {
                    Text("Recommended: \(nextAction.title)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(result.isSuccessful ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
        .transition(.scale.combined(with: .opacity))
    }
}

/// Recovery action button for environment object errors
struct EnvironmentRecoveryActionButton: View {
    let action: EnvironmentRecoveryAction
    let isLoading: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: action.icon)
                }
                
                Text(action.title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(actionButtonStyle)
        .disabled(isLoading)
    }
    
    private var actionButtonStyle: AnyButtonStyle {
        switch action.style {
        case .primary:
            return AnyButtonStyle(PrimaryButtonStyle())
        case .secondary:
            return AnyButtonStyle(SecondaryButtonStyle())
        case .tertiary:
            return AnyButtonStyle(TertiaryButtonStyle())
        case .destructive:
            return AnyButtonStyle(DestructiveButtonStyle())
        }
    }
}

// MARK: - Supporting Types

/// Context for environment object errors
struct EnvironmentErrorContext {
    let viewName: String?
    let showTechnicalDetails: Bool
    let allowRecovery: Bool
    
    static let `default` = EnvironmentErrorContext(
        viewName: nil,
        showTechnicalDetails: false,
        allowRecovery: true
    )
    
    init(viewName: String? = nil, showTechnicalDetails: Bool = false, allowRecovery: Bool = true) {
        self.viewName = viewName
        self.showTechnicalDetails = showTechnicalDetails
        self.allowRecovery = allowRecovery
    }
}

/// Recovery actions specific to environment object issues
enum EnvironmentRecoveryAction: String, CaseIterable, Hashable {
    case refreshEnvironment = "refresh_environment"
    case useDefaultState = "use_default_state"
    case restartView = "restart_view"
    case reportIssue = "report_issue"
    case checkDependencies = "check_dependencies"
    case resetNavigation = "reset_navigation"
    
    var title: String {
        switch self {
        case .refreshEnvironment:
            return "Refresh Environment"
        case .useDefaultState:
            return "Use Default State"
        case .restartView:
            return "Restart View"
        case .reportIssue:
            return "Report Issue"
        case .checkDependencies:
            return "Check Dependencies"
        case .resetNavigation:
            return "Reset Navigation"
        }
    }
    
    var icon: String {
        switch self {
        case .refreshEnvironment:
            return "arrow.clockwise"
        case .useDefaultState:
            return "gear"
        case .restartView:
            return "arrow.counterclockwise"
        case .reportIssue:
            return "exclamationmark.bubble"
        case .checkDependencies:
            return "checkmark.circle"
        case .resetNavigation:
            return "arrow.uturn.backward"
        }
    }
    
    var style: MockActionStyle {
        switch self {
        case .refreshEnvironment, .useDefaultState:
            return .primary
        case .restartView, .resetNavigation:
            return .secondary
        case .reportIssue, .checkDependencies:
            return .tertiary
        }
    }
}

/// Result of a recovery action
struct EnvironmentRecoveryResult {
    let action: EnvironmentRecoveryAction
    let isSuccessful: Bool
    let message: String
    let nextRecommendedAction: EnvironmentRecoveryAction?
}

// MARK: - Extensions

extension EnvironmentObjectError {
    /// User-friendly title for the error
    var userFriendlyTitle: String {
        switch self {
        case .missingEnvironmentObject:
            return "App State Not Available"
        case .invalidEnvironmentObjectState:
            return "App State Issue"
        case .fallbackCreationFailed:
            return "Fallback Creation Failed"
        case .dependencyInjectionFailure:
            return "Dependency Issue"
        }
    }
    
    /// User-friendly message for the error
    var userFriendlyMessage: String {
        switch self {
        case .missingEnvironmentObject(let type):
            if type == "AppState" {
                return "The app's main state is not properly initialized. This might cause some features to not work correctly."
            } else {
                return "A required component (\(type)) is not available. Some features might be limited."
            }
        case .invalidEnvironmentObjectState(let type, _):
            if type == "AppState" {
                return "The app's state has some inconsistencies. We'll try to fix this automatically."
            } else {
                return "There's an issue with the \(type) component. We'll attempt to resolve this."
            }
        case .fallbackCreationFailed(let type, _):
            return "We couldn't create a backup \(type) to keep the app running. Some features may be unavailable."
        case .dependencyInjectionFailure:
            return "There's a problem with how the app components are connected. We'll try to fix this."
        }
    }
    
    /// Category of the error for display
    var category: String {
        switch self {
        case .missingEnvironmentObject:
            return "Missing Component"
        case .invalidEnvironmentObjectState:
            return "State Issue"
        case .fallbackCreationFailed:
            return "Fallback Failed"
        case .dependencyInjectionFailure:
            return "Dependency Issue"
        }
    }
    
    /// Icon for the error
    var icon: String {
        switch self {
        case .missingEnvironmentObject:
            return "exclamationmark.triangle.fill"
        case .invalidEnvironmentObjectState:
            return "gear.badge.xmark"
        case .fallbackCreationFailed:
            return "xmark.circle.fill"
        case .dependencyInjectionFailure:
            return "link.badge.plus"
        }
    }
    
    /// Color for the error
    var color: Color {
        switch self {
        case .missingEnvironmentObject:
            return .orange
        case .invalidEnvironmentObjectState:
            return .red
        case .fallbackCreationFailed:
            return .red
        case .dependencyInjectionFailure:
            return .purple
        }
    }
    
    /// Available recovery actions for this error
    var availableRecoveryActions: [EnvironmentRecoveryAction] {
        switch self {
        case .missingEnvironmentObject(let type):
            if type == "AppState" {
                return [.useDefaultState, .refreshEnvironment, .restartView, .reportIssue]
            } else {
                return [.checkDependencies, .useDefaultState, .reportIssue]
            }
        case .invalidEnvironmentObjectState:
            return [.refreshEnvironment, .useDefaultState, .resetNavigation, .reportIssue]
        case .fallbackCreationFailed:
            return [.restartView, .reportIssue]
        case .dependencyInjectionFailure:
            return [.checkDependencies, .refreshEnvironment, .reportIssue]
        }
    }
}

// MARK: - Preview

#Preview("Environment Object Error View") {
    EnvironmentObjectErrorView(
        error: .missingEnvironmentObject(type: "AppState"),
        context: EnvironmentErrorContext(
            viewName: "ScheduledRunsListView",
            showTechnicalDetails: true,
            allowRecovery: true
        ),
        onRecoveryAction: { action in
            print("Recovery action: \(action)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
}

#Preview("Invalid State Error") {
    EnvironmentObjectErrorView(
        error: .invalidEnvironmentObjectState(
            type: "AppState",
            reason: "Navigation state is inconsistent"
        ),
        context: .default,
        onRecoveryAction: { _ in },
        onDismiss: {}
    )
}

#Preview("Dependency Injection Error") {
    EnvironmentObjectErrorView(
        error: .dependencyInjectionFailure("Multiple dependencies missing"),
        context: EnvironmentErrorContext(
            viewName: "SchoolRunDashboardView",
            showTechnicalDetails: false,
            allowRecovery: true
        ),
        onRecoveryAction: { _ in },
        onDismiss: {}
    )
}