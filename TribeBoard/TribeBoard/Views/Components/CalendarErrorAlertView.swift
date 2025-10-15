import SwiftUI
import SwiftData

/// Enhanced error alert view with recovery options and detailed error information
struct CalendarErrorAlertView: View {
    
    // MARK: - Properties
    
    @ObservedObject var errorViewModel: CalendarErrorStateViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRecoveryOption: CalendarErrorRecoveryOption?
    @State private var isShowingRecoveryOptions = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let error = errorViewModel.currentError {
                        // Error Header
                        errorHeaderSection(error)
                        
                        // Error Message
                        errorMessageSection(error)
                        
                        // Recovery Options
                        if !errorViewModel.availableRecoveryOptions.isEmpty {
                            recoveryOptionsSection
                        }
                        
                        // Error Details (if enabled)
                        if errorViewModel.showErrorDetails {
                            errorDetailsSection(error)
                        }
                        
                        // Action Buttons
                        actionButtonsSection(error)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Error")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        errorViewModel.dismissError()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(errorViewModel.showErrorDetails ? "Hide Details" : "Show Details") {
                        errorViewModel.toggleErrorDetails()
                    }
                    .font(.caption)
                }
            }
        }
        .overlay {
            if errorViewModel.isRecovering {
                recoveryProgressOverlay
            }
        }
    }
    
    // MARK: - View Components
    
    private func errorHeaderSection(_ error: CalendarError) -> some View {
        VStack(spacing: 16) {
            // Error Icon
            Image(systemName: error.category.icon)
                .font(.system(size: 60, weight: .medium))
                .foregroundColor(errorViewModel.getErrorColor(for: error))
                .accessibilityHidden(true)
            
            // Error Category and Severity
            VStack(spacing: 4) {
                Text(error.category.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                HStack {
                    Text("Severity:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(error.severity.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(errorViewModel.getErrorColor(for: error).opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error.category.displayName), Severity: \(error.severity.displayName)")
    }
    
    private func errorMessageSection(_ error: CalendarError) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Primary Error Message
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            // Failure Reason (if available)
            if let failureReason = error.failureReason {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What happened:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Text(failureReason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Recovery Suggestion (if available)
            if let recoverySuggestion = error.recoverySuggestion {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.orange)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How to fix:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Text(recoverySuggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error details and suggestions")
    }
    
    private var recoveryOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundColor(.green)
                
                Text("Recovery Options")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(errorViewModel.availableRecoveryOptions) { option in
                    RecoveryOptionRow(
                        option: option,
                        isSelected: selectedRecoveryOption?.id == option.id,
                        onTap: {
                            selectedRecoveryOption = option
                            Task {
                                await errorViewModel.executeRecoveryAction(option)
                            }
                        }
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recovery options")
    }
    
    private func errorDetailsSection(_ error: CalendarError) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.secondary)
                
                Text("Technical Details")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if let context = errorViewModel.errorContext {
                    DetailRow(label: "Operation", value: context.operation)
                    DetailRow(label: "Timestamp", value: formatTimestamp(context.timestamp))
                    
                    if let userId = context.userId {
                        DetailRow(label: "User ID", value: String(userId.prefix(8)) + "...")
                    }
                    
                    if let familyId = context.familyId {
                        DetailRow(label: "Family ID", value: String(familyId.prefix(8)) + "...")
                    }
                    
                    if let eventId = context.eventId {
                        DetailRow(label: "Event ID", value: String(eventId.prefix(8)) + "...")
                    }
                    
                    if !context.additionalInfo.isEmpty {
                        ForEach(Array(context.additionalInfo.keys.sorted()), id: \.self) { key in
                            if let value = context.additionalInfo[key] {
                                DetailRow(label: key.capitalized, value: String(describing: value))
                            }
                        }
                    }
                }
                
                DetailRow(label: "Error Code", value: String(describing: error))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Technical error details")
    }
    
    private func actionButtonsSection(_ error: CalendarError) -> some View {
        VStack(spacing: 12) {
            // Primary Action Button
            if errorViewModel.retryAction != nil && canRetry(error) {
                Button(action: {
                    Task {
                        await errorViewModel.retryOperation()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(errorViewModel.getErrorColor(for: error))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(errorViewModel.isRecovering)
                .accessibilityLabel("Retry the failed operation")
            }
            
            // Secondary Actions
            HStack(spacing: 12) {
                // Contact Support (for critical errors)
                if error.severity == .critical {
                    Button(action: {
                        // Open support contact
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Get Help")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Contact support for help")
                }
                
                Spacer()
                
                // Dismiss Button
                Button("Dismiss") {
                    errorViewModel.dismissError()
                    dismiss()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityLabel("Dismiss error message")
            }
        }
    }
    
    private var recoveryProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView(value: errorViewModel.recoveryProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)
                
                Text(errorViewModel.recoveryMessage)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recovery in progress: \(errorViewModel.recoveryMessage)")
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
    
    private struct RecoveryOptionRow: View {
        let option: CalendarErrorRecoveryOption
        let isSelected: Bool
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Priority Indicator
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(option.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    if option.isAutomated {
                        Image(systemName: "gear")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("\(option.title): \(option.description)")
            .accessibilityHint(option.isAutomated ? "Automated recovery option" : "Manual recovery option")
        }
        
        private var priorityColor: Color {
            switch option.priority {
            case .low: return .gray
            case .medium: return .orange
            case .high: return .red
            case .critical: return .purple
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func canRetry(_ error: CalendarError) -> Bool {
        switch error.category {
        case .network, .sync, .data:
            return true
        case .validation, .permission, .businessLogic, .configuration:
            return false
        }
    }
    
    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Preview

#Preview("Validation Error") {
    // Simplified preview without complex dependencies
    let viewModel = CalendarErrorStateViewModel.networkError(
        CalendarError.networkUnavailable,
        operation: "sync events",
        retryAction: {},
        recoveryService: nil
    )
    
    CalendarErrorAlertView(errorViewModel: viewModel)
}

#Preview("Network Error") {
    
    let viewModel = CalendarErrorStateViewModel.networkError(
        CalendarError.networkUnavailable,
        operation: "sync events",
        retryAction: {},
        recoveryService: nil
    )
    
    CalendarErrorAlertView(errorViewModel: viewModel)
}