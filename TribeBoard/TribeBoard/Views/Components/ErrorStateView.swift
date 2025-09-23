import SwiftUI

// MARK: - AnyButtonStyle wrapper
struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView
    
    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

/// Reusable error state view with consistent styling and actions
struct ErrorStateView: View {
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let dismissAction: (() -> Void)?
    let errorType: ErrorType
    
    enum ErrorType {
        case network
        case validation
        case authentication
        case permission
        case notFound
        case generic
        case info
        
        var icon: String {
            switch self {
            case .network:
                return "wifi.exclamationmark"
            case .validation:
                return "exclamationmark.triangle.fill"
            case .authentication:
                return "person.crop.circle.badge.exclamationmark"
            case .permission:
                return "lock.fill"
            case .notFound:
                return "questionmark.circle.fill"
            case .generic:
                return "exclamationmark.triangle.fill"
            case .info:
                return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .network:
                return .orange
            case .validation:
                return .red
            case .authentication:
                return .blue
            case .permission:
                return .purple
            case .notFound:
                return .gray
            case .generic:
                return .red
            case .info:
                return .blue
            }
        }
    }
    
    init(
        title: String = "Something went wrong",
        message: String,
        actionTitle: String? = "Try Again",
        action: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil,
        errorType: ErrorType = .generic
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.dismissAction = dismissAction
        self.errorType = errorType
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Error icon
            Image(systemName: errorType.icon)
                .font(.system(size: 48))
                .foregroundColor(errorType.color)
            
            // Error content
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Action buttons
            VStack(spacing: 12) {
                if let action = action, let actionTitle = actionTitle {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                
                if let dismissAction = dismissAction {
                    Button("Dismiss", action: dismissAction)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(
                    color: BrandStyle.standardShadow,
                    radius: BrandStyle.shadowRadius,
                    x: BrandStyle.shadowOffset.width,
                    y: BrandStyle.shadowOffset.height
                )
        )
        .padding(.horizontal, 20)
    }
}

/// Inline error message component for forms and inputs
struct InlineErrorView: View {
    let message: String
    let onDismiss: (() -> Void)?
    
    init(message: String, onDismiss: (() -> Void)? = nil) {
        self.message = message
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.red)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            
            Spacer()
            
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.scale.combined(with: .opacity))
    }
}

/// Success message component
struct SuccessMessageView: View {
    let message: String
    let onDismiss: (() -> Void)?
    
    init(message: String, onDismiss: (() -> Void)? = nil) {
        self.message = message
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.green)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            
            Spacer()
            
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Enhanced Mock Error Display

/// Enhanced error state view that integrates with MockErrorGenerator
struct EnhancedErrorStateView: View {
    let error: MockError
    let recoveryManager: MockErrorRecoveryManager
    let onDismiss: (() -> Void)?
    
    @State private var isRecovering = false
    @State private var recoveryResult: MockRecoveryResult?
    
    var body: some View {
        VStack(spacing: 20) {
            // Error icon and severity indicator
            HStack {
                Image(systemName: error.category.icon)
                    .font(.system(size: 32))
                    .foregroundColor(severityColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.severity.displayName.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(severityColor)
                    
                    Text(error.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Error content
            VStack(spacing: 12) {
                Text(error.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(error.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Recovery progress (if active)
            if let progress = recoveryManager.recoveryProgress {
                RecoveryProgressView(progress: progress)
            }
            
            // Recovery result (if available)
            if let result = recoveryResult {
                RecoveryResultView(result: result)
            }
            
            // Recovery actions
            VStack(spacing: 12) {
                ForEach(error.recoveryActions.prefix(3), id: \.self) { action in
                    RecoveryActionButton(
                        action: action,
                        isLoading: isRecovering,
                        onTap: {
                            Task {
                                await executeRecoveryAction(action)
                            }
                        }
                    )
                }
                
                // Show more actions if available
                if error.recoveryActions.count > 3 {
                    DisclosureGroup("More Options") {
                        VStack(spacing: 8) {
                            ForEach(error.recoveryActions.dropFirst(3), id: \.self) { action in
                                RecoveryActionButton(
                                    action: action,
                                    isLoading: isRecovering,
                                    onTap: {
                                        Task {
                                            await executeRecoveryAction(action)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .font(.subheadline)
                }
                
                // Dismiss button
                if let onDismiss = onDismiss {
                    Button("Dismiss", action: onDismiss)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(
                    color: BrandStyle.standardShadow,
                    radius: BrandStyle.shadowRadius,
                    x: BrandStyle.shadowOffset.width,
                    y: BrandStyle.shadowOffset.height
                )
        )
        .padding(.horizontal, 20)
        .onAppear {
            recoveryManager.startRecoveryFlow(for: error)
        }
    }
    
    private var severityColor: Color {
        switch error.severity {
        case .info:
            return .blue
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
    
    private func executeRecoveryAction(_ action: MockRecoveryAction) async {
        isRecovering = true
        recoveryResult = nil
        
        let result = await recoveryManager.executeRecoveryAction(action, for: error)
        
        recoveryResult = result
        isRecovering = false
        
        // Auto-dismiss on success for certain actions
        if result.isSuccessful && [.dismiss, .continueDemo, .workOffline].contains(action) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onDismiss?()
            }
        }
    }
}

/// Recovery action button component
struct RecoveryActionButton: View {
    let action: MockRecoveryAction
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

/// Recovery progress indicator
struct RecoveryProgressView: View {
    let progress: MockRecoveryProgress
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Recovery Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(progress.currentStep)/\(progress.totalSteps)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress.progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            if progress.isComplete {
                HStack {
                    Image(systemName: progress.hasSucceeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(progress.hasSucceeded ? .green : .red)
                    
                    Text(progress.hasSucceeded ? "Recovery completed" : "Recovery failed")
                        .font(.caption)
                        .foregroundColor(progress.hasSucceeded ? .green : .red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

/// Recovery result display
struct RecoveryResultView: View {
    let result: MockRecoveryResult
    
    var body: some View {
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

// MARK: - Mock Error Scenarios

struct MockErrorScenarios {
    
    // MARK: - Network Errors
    
    static func networkError(onRetry: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Connection Lost",
            message: "Unable to connect to TribeBoard servers. Please check your internet connection and try again.",
            actionTitle: "Retry Connection",
            action: {
                HapticManager.shared.lightImpact()
                onRetry()
                ToastManager.shared.info("Retrying connection...")
            },
            errorType: .network
        )
    }
    
    static func offlineError(onContinueOffline: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "You're Offline",
            message: "No internet connection detected. You can continue using TribeBoard with limited functionality.",
            actionTitle: "Continue Offline",
            action: {
                HapticManager.shared.selection()
                onContinueOffline()
                ToastManager.shared.info("Working offline - changes will sync when connected")
            },
            errorType: .network
        )
    }
    
    // MARK: - Authentication Errors
    
    static func authenticationError(onSignIn: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Sign In Required",
            message: "Your session has expired. Please sign in again to continue using TribeBoard.",
            actionTitle: "Sign In",
            action: {
                HapticManager.shared.selection()
                onSignIn()
            },
            errorType: .authentication
        )
    }
    
    static func accountNotFound(onCreateAccount: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Account Not Found",
            message: "We couldn't find an account with those credentials. Would you like to create a new account?",
            actionTitle: "Create Account",
            action: {
                HapticManager.shared.selection()
                onCreateAccount()
            },
            errorType: .authentication
        )
    }
    
    // MARK: - Family Management Errors
    
    static func familyNotFound(onTryAgain: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Family Not Found",
            message: "The family code 'ABC123' doesn't exist. Please check the code and try again, or ask your family admin for the correct code.",
            actionTitle: "Try Different Code",
            action: {
                HapticManager.shared.lightImpact()
                onTryAgain()
            },
            errorType: .notFound
        )
    }
    
    static func familyFull(onContactAdmin: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Family is Full",
            message: "This family has reached its maximum number of members. Contact the family admin to make space or upgrade the plan.",
            actionTitle: "Contact Admin",
            action: {
                HapticManager.shared.selection()
                onContactAdmin()
                ToastManager.shared.info("Opening contact options...")
            },
            errorType: .permission
        )
    }
    
    static func alreadyInFamily(onSwitchFamily: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Already in Family",
            message: "You're already a member of the 'Mawere Family'. You can only be in one family at a time.",
            actionTitle: "Switch Families",
            action: {
                HapticManager.shared.warning()
                onSwitchFamily()
            },
            errorType: .validation
        )
    }
    
    // MARK: - Permission Errors
    
    static func permissionDenied(onContactAdmin: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Access Denied",
            message: "You don't have permission to perform this action. Only family admins can manage members and settings.",
            actionTitle: "Contact Admin",
            action: {
                HapticManager.shared.selection()
                onContactAdmin()
                ToastManager.shared.info("Contacting family admin...")
            },
            errorType: .permission
        )
    }
    
    static func childRestriction(onRequestPermission: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Parental Permission Required",
            message: "This feature requires parental permission. We'll send a request to your parents for approval.",
            actionTitle: "Request Permission",
            action: {
                HapticManager.shared.selection()
                onRequestPermission()
                ToastManager.shared.success("Permission request sent to parents")
            },
            errorType: .permission
        )
    }
    
    // MARK: - Validation Errors
    
    static func validationError(onReviewForm: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Invalid Information",
            message: "Please check your input and make sure all required fields are filled correctly. Family name must be at least 2 characters.",
            actionTitle: "Review Form",
            action: {
                HapticManager.shared.lightImpact()
                onReviewForm()
            },
            errorType: .validation
        )
    }
    
    static func duplicateFamilyName(onChooseDifferent: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Family Name Taken",
            message: "A family with the name 'Mawere Family' already exists. Please choose a different name or add a unique identifier.",
            actionTitle: "Choose Different Name",
            action: {
                HapticManager.shared.selection()
                onChooseDifferent()
            },
            errorType: .validation
        )
    }
    
    // MARK: - Data Errors
    
    static func syncError(onForcSync: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Sync Failed",
            message: "Some of your changes couldn't be synced. Your data is safe locally and will sync when connection improves.",
            actionTitle: "Force Sync",
            action: {
                HapticManager.shared.lightImpact()
                onForcSync()
                ToastManager.shared.info("Attempting to sync...")
            },
            errorType: .network
        )
    }
    
    static func dataCorruption(onResetData: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Data Issue Detected",
            message: "We detected an issue with your local data. Don't worry - your family data is safely stored in the cloud and can be restored.",
            actionTitle: "Restore Data",
            action: {
                HapticManager.shared.warning()
                onResetData()
                ToastManager.shared.info("Restoring data from cloud...")
            },
            errorType: .generic
        )
    }
    
    // MARK: - Feature-Specific Errors
    
    static func qrScanError(onTryAgain: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "QR Code Not Recognized",
            message: "The QR code couldn't be read or isn't a valid TribeBoard family code. Make sure the code is clear and try again.",
            actionTitle: "Try Again",
            action: {
                HapticManager.shared.lightImpact()
                onTryAgain()
            },
            errorType: .validation
        )
    }
    
    static func cameraPermission(onOpenSettings: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Camera Access Needed",
            message: "TribeBoard needs camera access to scan QR codes. Please enable camera permission in Settings.",
            actionTitle: "Open Settings",
            action: {
                HapticManager.shared.selection()
                onOpenSettings()
            },
            errorType: .permission
        )
    }
    
    // MARK: - Prototype-Specific Errors
    
    static func prototypeDataLimitReached(onContinue: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Demo Data Limit",
            message: "You've reached the demo data limit. In the full app, you can add unlimited family members and content.",
            actionTitle: "Continue Demo",
            action: {
                HapticManager.shared.selection()
                onContinue()
                ToastManager.shared.info("Continuing with existing demo data")
            },
            errorType: .info
        )
    }
    
    static func prototypeFeaturePreview(featureName: String, onLearnMore: @escaping () -> Void = {}) -> ErrorStateView {
        ErrorStateView(
            title: "Feature Preview",
            message: "\(featureName) is available in the full version. This prototype shows the interface design and user flow.",
            actionTitle: "Learn More",
            action: {
                HapticManager.shared.selection()
                onLearnMore()
                ToastManager.shared.info("Feature information displayed")
            },
            errorType: .info
        )
    }
    
    // MARK: - Random Error Generator
    
    static func randomError() -> ErrorStateView {
        let errorGenerators: [() -> ErrorStateView] = [
            { networkError() },
            { authenticationError() },
            { familyNotFound() },
            { permissionDenied() },
            { validationError() },
            { familyFull() },
            { syncError() },
            { qrScanError() }
        ]
        
        return errorGenerators.randomElement()?() ?? networkError()
    }
    
    static func randomPrototypeError() -> ErrorStateView {
        let prototypeErrors: [() -> ErrorStateView] = [
            { prototypeDataLimitReached() },
            { prototypeFeaturePreview(featureName: "Advanced Analytics") },
            { prototypeFeaturePreview(featureName: "Video Calling") },
            { prototypeFeaturePreview(featureName: "Location Sharing") }
        ]
        
        return prototypeErrors.randomElement()?() ?? prototypeDataLimitReached()
    }
    
    // MARK: - Context-Specific Error Sets
    
    static func familyCreationErrors() -> [ErrorStateView] {
        return [
            duplicateFamilyName(),
            validationError(),
            networkError(),
            authenticationError()
        ]
    }
    
    static func familyJoiningErrors() -> [ErrorStateView] {
        return [
            familyNotFound(),
            familyFull(),
            alreadyInFamily(),
            qrScanError(),
            networkError()
        ]
    }
    
    static func permissionErrors() -> [ErrorStateView] {
        return [
            permissionDenied(),
            childRestriction(),
            cameraPermission()
        ]
    }
}

// MARK: - Preview

#Preview("Error State View") {
    ErrorStateView(
        title: "Network Error",
        message: "Unable to connect to the server. Please check your internet connection and try again.",
        actionTitle: "Retry",
        action: {},
        dismissAction: {},
        errorType: .network
    )
}

#Preview("Mock Error Scenarios") {
    ScrollView {
        VStack(spacing: 30) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Network Errors")
                    .font(.headline)
                VStack(spacing: 16) {
                    MockErrorScenarios.networkError()
                    MockErrorScenarios.offlineError()
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Management Errors")
                    .font(.headline)
                VStack(spacing: 16) {
                    MockErrorScenarios.familyNotFound()
                    MockErrorScenarios.familyFull()
                    MockErrorScenarios.alreadyInFamily()
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Permission Errors")
                    .font(.headline)
                VStack(spacing: 16) {
                    MockErrorScenarios.permissionDenied()
                    MockErrorScenarios.childRestriction()
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Validation Errors")
                    .font(.headline)
                VStack(spacing: 16) {
                    MockErrorScenarios.validationError()
                    MockErrorScenarios.duplicateFamilyName()
                    MockErrorScenarios.qrScanError()
                }
            }
        }
        .padding()
    }
}

#Preview("Inline Error") {
    VStack(spacing: 16) {
        InlineErrorView(
            message: "Family name must be at least 2 characters",
            onDismiss: {}
        )
        
        SuccessMessageView(
            message: "Family created successfully!",
            onDismiss: {}
        )
    }
    .padding()
}