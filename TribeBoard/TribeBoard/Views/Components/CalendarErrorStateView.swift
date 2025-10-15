import SwiftUI
import UIKit

/// Comprehensive error state view for calendar operations with retry functionality and user guidance
struct CalendarErrorStateView: View {
    
    // MARK: - Properties
    
    let error: CalendarError
    let context: CalendarErrorContext?
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    let showDetails: Bool
    
    @State private var isShowingDetails = false
    @State private var isRetrying = false
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Initialization
    
    init(
        error: CalendarError,
        context: CalendarErrorContext? = nil,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        showDetails: Bool = false
    ) {
        self.error = error
        self.context = context
        self.onRetry = onRetry
        self.onDismiss = onDismiss
        self.showDetails = showDetails
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            // Error Icon and Category
            errorHeader
            
            // Error Message
            errorMessage
            
            // Recovery Suggestions
            recoverySuggestions
            
            // Action Buttons
            actionButtons
            
            // Error Details (if enabled)
            if showDetails {
                errorDetails
            }
        }
        .padding(24)
        .background(errorBackgroundColor)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(errorBorderColor, lineWidth: 1)
        )
    }
    
    // MARK: - View Components
    
    private var errorHeader: some View {
        VStack(spacing: 12) {
            // Error Icon
            Image(systemName: error.category.icon)
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(errorIconColor)
                .accessibilityHidden(true)
            
            // Error Category
            Text(error.category.displayName)
                .font(.headline)
                .foregroundColor(.secondary)
                .accessibilityLabel("Error category: \(error.category.displayName)")
        }
    }
    
    private var errorMessage: some View {
        VStack(spacing: 8) {
            // Primary Error Message
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .accessibilityLabel("Error message: \(error.localizedDescription)")
            
            // Failure Reason (if available)
            if let failureReason = error.failureReason {
                Text(failureReason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Failure reason: \(failureReason)")
            }
        }
    }
    
    private var recoverySuggestions: some View {
        Group {
            if let recoverySuggestion = error.recoverySuggestion {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.orange)
                            .accessibilityHidden(true)
                        
                        Text("How to fix this:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text(recoverySuggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Recovery suggestion: \(recoverySuggestion)")
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary Action (Retry)
            if let onRetry = onRetry, canRetry {
                Button(action: {
                    performRetry()
                }) {
                    HStack {
                        if isRetrying {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Text(isRetrying ? "Retrying..." : "Try Again")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(retryButtonColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isRetrying)
                .accessibilityLabel(isRetrying ? "Retrying operation" : "Retry the failed operation")
            }
            
            // Secondary Actions
            HStack(spacing: 12) {
                // Show Details Button
                if showDetails {
                    Button(action: {
                        isShowingDetails.toggle()
                    }) {
                        HStack {
                            Image(systemName: isShowingDetails ? "chevron.up" : "chevron.down")
                            Text(isShowingDetails ? "Hide Details" : "Show Details")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(isShowingDetails ? "Hide error details" : "Show error details")
                }
                
                Spacer()
                
                // Dismiss Button
                if let onDismiss = onDismiss {
                    Button("Dismiss", action: onDismiss)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Dismiss error message")
                }
            }
        }
    }
    
    private var errorDetails: some View {
        Group {
            if isShowingDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Text("Error Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        DetailRow(label: "Severity", value: error.severity.displayName)
                        DetailRow(label: "Category", value: error.category.displayName)
                        
                        if let context = context {
                            DetailRow(label: "Operation", value: context.operation)
                            DetailRow(label: "Time", value: formatTimestamp(context.timestamp))
                            
                            if let userId = context.userId {
                                DetailRow(label: "User ID", value: String(userId.prefix(8)) + "...")
                            }
                            
                            if let familyId = context.familyId {
                                DetailRow(label: "Family ID", value: String(familyId.prefix(8)) + "...")
                            }
                            
                            if let eventId = context.eventId {
                                DetailRow(label: "Event ID", value: String(eventId.prefix(8)) + "...")
                            }
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Error details section")
            }
        }
    }
    
    // MARK: - Helper Views
    
    private struct DetailRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Text("\(label):")
                    .fontWeight(.medium)
                Spacer()
                Text(value)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canRetry: Bool {
        switch error.category {
        case .network, .sync, .data:
            return true
        case .validation, .permission, .businessLogic, .configuration:
            return false
        }
    }
    
    private var errorBackgroundColor: Color {
        switch error.severity {
        case .low:
            return Color.blue.opacity(0.05)
        case .medium:
            return Color.orange.opacity(0.05)
        case .high:
            return Color.red.opacity(0.05)
        case .critical:
            return Color.purple.opacity(0.05)
        }
    }
    
    private var errorBorderColor: Color {
        switch error.severity {
        case .low:
            return Color.blue.opacity(0.2)
        case .medium:
            return Color.orange.opacity(0.2)
        case .high:
            return Color.red.opacity(0.2)
        case .critical:
            return Color.purple.opacity(0.2)
        }
    }
    
    private var errorIconColor: Color {
        switch error.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
    
    private var retryButtonColor: Color {
        switch error.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
    
    // MARK: - Actions
    
    private func performRetry() {
        guard let onRetry = onRetry else { return }
        
        isRetrying = true
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Simulate retry delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onRetry()
            isRetrying = false
        }
    }
    
    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Convenience Initializers

extension CalendarErrorStateView {
    
    /// Creates an error state view for validation errors
    static func validation(
        error: CalendarError,
        onDismiss: @escaping () -> Void
    ) -> CalendarErrorStateView {
        CalendarErrorStateView(
            error: error,
            onRetry: nil,
            onDismiss: onDismiss,
            showDetails: false
        )
    }
    
    /// Creates an error state view for network errors with retry
    static func network(
        error: CalendarError,
        onRetry: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> CalendarErrorStateView {
        CalendarErrorStateView(
            error: error,
            onRetry: onRetry,
            onDismiss: onDismiss,
            showDetails: true
        )
    }
    
    /// Creates an error state view for sync errors with retry
    static func sync(
        error: CalendarError,
        context: CalendarErrorContext,
        onRetry: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> CalendarErrorStateView {
        CalendarErrorStateView(
            error: error,
            context: context,
            onRetry: onRetry,
            onDismiss: onDismiss,
            showDetails: true
        )
    }
    
    /// Creates an error state view for permission errors
    static func permission(
        error: CalendarError,
        context: CalendarErrorContext,
        onDismiss: @escaping () -> Void
    ) -> CalendarErrorStateView {
        CalendarErrorStateView(
            error: error,
            context: context,
            onRetry: nil,
            onDismiss: onDismiss,
            showDetails: true
        )
    }
}

// MARK: - Preview

#Preview("Validation Error") {
    CalendarErrorStateView.validation(
        error: .invalidEventTitle(""),
        onDismiss: {}
    )
    .padding()
}

#Preview("Network Error") {
    CalendarErrorStateView.network(
        error: .networkUnavailable,
        onRetry: {},
        onDismiss: {}
    )
    .padding()
}

#Preview("Sync Error") {
    CalendarErrorStateView.sync(
        error: .syncConflictDetected(localEvent: "Meeting", remoteEvent: "Conference"),
        context: CalendarErrorContext(
            userId: "user123",
            familyId: "family456",
            eventId: "event789",
            operation: "syncEvent"
        ),
        onRetry: {},
        onDismiss: {}
    )
    .padding()
}

#Preview("Permission Error") {
    CalendarErrorStateView.permission(
        error: .insufficientPermissions(operation: "create family event", required: "calendar admin"),
        context: CalendarErrorContext(
            userId: "user123",
            familyId: "family456",
            operation: "createFamilyEvent"
        ),
        onDismiss: {}
    )
    .padding()
}