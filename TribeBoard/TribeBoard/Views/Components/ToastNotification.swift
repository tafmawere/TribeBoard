import SwiftUI

/// Toast notification system for non-blocking user feedback
struct ToastNotification: View {
    let message: String
    let type: ToastType
    let duration: TimeInterval
    let onDismiss: (() -> Void)?
    
    @State private var isVisible = false
    @State private var offset: CGFloat = -100
    
    enum ToastType {
        case success
        case error
        case warning
        case info
        
        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "xmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .info:
                return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success:
                return .green
            case .error:
                return .red
            case .warning:
                return .orange
            case .info:
                return .blue
            }
        }
    }
    
    init(
        message: String,
        type: ToastType,
        duration: TimeInterval = 3.0,
        onDismiss: (() -> Void)? = nil
    ) {
        self.message = message
        self.type = type
        self.duration = duration
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title3)
                .foregroundColor(type.color)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(
                    color: BrandStyle.standardShadow,
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, 16)
        .offset(y: offset)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            showToast()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(type.accessibilityLabel): \(message)")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityAction(named: "Dismiss") {
            dismiss()
        }
    }
    
    private func showToast() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isVisible = true
            offset = 0
        }
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            dismiss()
        }
        
        // Haptic feedback
        switch type {
        case .success:
            HapticManager.shared.success()
        case .error:
            HapticManager.shared.error()
        case .warning:
            HapticManager.shared.warning()
        case .info:
            HapticManager.shared.lightImpact()
        }
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
}

extension ToastNotification.ToastType {
    var accessibilityLabel: String {
        switch self {
        case .success:
            return "Success"
        case .error:
            return "Error"
        case .warning:
            return "Warning"
        case .info:
            return "Information"
        }
    }
}

/// Toast manager for showing toasts from anywhere in the app
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: ToastData?
    
    private init() {}
    
    func show(
        message: String,
        type: ToastNotification.ToastType,
        duration: TimeInterval = 3.0
    ) {
        currentToast = ToastData(
            message: message,
            type: type,
            duration: duration
        )
    }
    
    func dismiss() {
        currentToast = nil
    }
    
    // Convenience methods
    func success(_ message: String) {
        show(message: message, type: .success)
    }
    
    func error(_ message: String) {
        show(message: message, type: .error)
    }
    
    func warning(_ message: String) {
        show(message: message, type: .warning)
    }
    
    func info(_ message: String) {
        show(message: message, type: .info)
    }
    
    // MARK: - Mock Toast Messages
    
    // MARK: Success Messages
    
    func showMockFamilyCreated() {
        success("🎉 Family created successfully! Share code ABC123 with family members.")
    }
    
    func showMockFamilyJoined() {
        success("🏠 Welcome to the Mawere Family! You're now connected with your loved ones.")
    }
    
    func showMockTaskCompleted() {
        success("✅ Great job! Task marked as complete. You earned 10 points!")
    }
    
    func showMockMessageSent() {
        success("💬 Message sent to family group")
    }
    
    func showMockProfileUpdated() {
        success("👤 Profile updated successfully")
    }
    
    func showMockRoleAssigned() {
        success("🎭 Role updated to Parent Admin")
    }
    
    func showMockEventCreated() {
        success("📅 Family dinner added to calendar")
    }
    
    func showMockPickupScheduled() {
        success("🚗 School pickup scheduled for 3:30 PM")
    }
    
    func showMockInvitationSent() {
        success("📧 Invitation sent to john@example.com")
    }
    
    func showMockDataSynced() {
        success("☁️ All changes synced successfully")
    }
    
    func showMockSettingsSaved() {
        success("⚙️ Settings saved and applied")
    }
    
    func showMockQRCodeGenerated() {
        success("📱 QR code generated and ready to share")
    }
    
    // MARK: Error Messages
    
    func showMockNetworkError() {
        error("📡 Connection lost. Please check your internet and try again.")
    }
    
    func showMockValidationError() {
        error("⚠️ Please check your input and try again")
    }
    
    func showMockPermissionError() {
        error("🔒 You don't have permission to perform this action")
    }
    
    func showMockFamilyCodeError() {
        error("🔍 Family code 'XYZ789' not found. Please check and try again.")
    }
    
    func showMockAuthenticationError() {
        error("🔐 Sign in failed. Please try again.")
    }
    
    func showMockSyncError() {
        error("☁️ Sync failed. Your changes are saved locally.")
    }
    
    func showMockCameraError() {
        error("📷 Camera access denied. Enable in Settings to scan QR codes.")
    }
    
    func showMockServerError() {
        error("🔧 Server temporarily unavailable. Please try again later.")
    }
    
    // MARK: Warning Messages
    
    func showMockSyncWarning() {
        warning("⏳ Some changes haven't synced yet. They'll sync when connection improves.")
    }
    
    func showMockBatteryWarning() {
        warning("🔋 Low battery may affect location tracking for school runs.")
    }
    
    func showMockStorageWarning() {
        warning("💾 Storage almost full. Consider removing old photos.")
    }
    
    func showMockPermissionWarning() {
        warning("👨‍👩‍👧‍👦 This action requires parent approval.")
    }
    
    func showMockOfflineWarning() {
        warning("📶 Limited connectivity. Some features may not work.")
    }
    
    // MARK: Info Messages
    
    func showMockOfflineMode() {
        info("📱 You're offline. Changes will sync when connection is restored.")
    }
    
    func showMockNewFeature() {
        info("✨ New feature: Family calendar is now available!")
    }
    
    func showMockMaintenanceMode() {
        info("🔧 Scheduled maintenance in 30 minutes. Save your work.")
    }
    
    func showMockTipOfTheDay() {
        info("💡 Tip: Tap and hold messages to react with emojis!")
    }
    
    func showMockLocationSharing() {
        info("📍 Location sharing enabled for school run tracking.")
    }
    
    func showMockBackupComplete() {
        info("💾 Family data backed up successfully.")
    }
    
    // MARK: Context-Specific Toast Sets
    
    func showRandomSuccessToast() {
        let successToasts: [() -> Void] = [
            showMockFamilyCreated,
            showMockFamilyJoined,
            showMockTaskCompleted,
            showMockMessageSent,
            showMockProfileUpdated,
            showMockRoleAssigned,
            showMockEventCreated,
            showMockPickupScheduled,
            showMockInvitationSent,
            showMockDataSynced,
            showMockSettingsSaved,
            showMockQRCodeGenerated
        ]
        
        successToasts.randomElement()?()
    }
    
    // MARK: - Prototype-Specific Toast Sequences
    
    func showPrototypeWelcomeSequence() {
        info("🎉 Welcome to TribeBoard prototype!")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            self.info("💡 All features use mock data for demonstration")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
            self.success("✨ Explore all features - no backend required!")
        }
    }
    
    func showDemoModeSequence() {
        info("🎭 Demo mode activated")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.info("📱 All interactions are simulated")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.success("🚀 Ready for demonstration!")
        }
    }
    
    func showRandomErrorToast() {
        let errorToasts: [() -> Void] = [
            showMockNetworkError,
            showMockValidationError,
            showMockPermissionError,
            showMockFamilyCodeError,
            showMockAuthenticationError,
            showMockSyncError,
            showMockCameraError,
            showMockServerError
        ]
        
        errorToasts.randomElement()?()
    }
    
    func showRandomWarningToast() {
        let warningToasts: [() -> Void] = [
            showMockSyncWarning,
            showMockBatteryWarning,
            showMockStorageWarning,
            showMockPermissionWarning,
            showMockOfflineWarning
        ]
        
        warningToasts.randomElement()?()
    }
    
    func showRandomInfoToast() {
        let infoToasts: [() -> Void] = [
            showMockOfflineMode,
            showMockNewFeature,
            showMockMaintenanceMode,
            showMockTipOfTheDay,
            showMockLocationSharing,
            showMockBackupComplete
        ]
        
        infoToasts.randomElement()?()
    }
    
    func showRandomMockToast() {
        let allToasts: [() -> Void] = [
            showRandomSuccessToast,
            showRandomErrorToast,
            showRandomWarningToast,
            showRandomInfoToast
        ]
        
        allToasts.randomElement()?()
    }
    
    // MARK: Feature-Specific Toasts
    
    func showFamilyCreationToasts() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.info("🔄 Generating family code...")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.success("🎉 Family 'Mawere Family' created! Code: ABC123")
        }
    }
    
    func showFamilyJoiningToasts() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.info("🔍 Searching for family...")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.success("🏠 Successfully joined the Mawere Family!")
        }
    }
    
    func showSyncSequenceToasts() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.info("☁️ Syncing family data...")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.warning("⏳ Large sync in progress...")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.success("✅ All data synced successfully!")
        }
    }
}

struct ToastData {
    let message: String
    let type: ToastNotification.ToastType
    let duration: TimeInterval
}

/// Toast container view modifier
struct ToastViewModifier: ViewModifier {
    @StateObject private var toastManager = ToastManager.shared
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if let toast = toastManager.currentToast {
                ToastNotification(
                    message: toast.message,
                    type: toast.type,
                    duration: toast.duration,
                    onDismiss: {
                        toastManager.dismiss()
                    }
                )
                .zIndex(1000)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

extension View {
    func withToast() -> some View {
        modifier(ToastViewModifier())
    }
}

/// Copy to clipboard with toast feedback
struct CopyableText: View {
    let text: String
    let displayText: String?
    let successMessage: String
    
    init(
        text: String,
        displayText: String? = nil,
        successMessage: String = "Copied to clipboard"
    ) {
        self.text = text
        self.displayText = displayText
        self.successMessage = successMessage
    }
    
    var body: some View {
        Button(action: copyToClipboard) {
            HStack(spacing: 8) {
                Text(displayText ?? text)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.brandPrimary)
            }
        }
        .accessibilityLabel("Copy \(displayText ?? text)")
        .accessibilityHint("Copies the text to clipboard")
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = text
        ToastManager.shared.success(successMessage)
        HapticManager.shared.lightImpact()
    }
}

// MARK: - Preview

#Preview("Toast Notifications") {
    ScrollView {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Success Toasts")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("Family Created") {
                        ToastManager.shared.showMockFamilyCreated()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Task Complete") {
                        ToastManager.shared.showMockTaskCompleted()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Random Success") {
                        ToastManager.shared.showRandomSuccessToast()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Error Toasts")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("Network Error") {
                        ToastManager.shared.showMockNetworkError()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Permission Error") {
                        ToastManager.shared.showMockPermissionError()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Random Error") {
                        ToastManager.shared.showRandomErrorToast()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Warning Toasts")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("Sync Warning") {
                        ToastManager.shared.showMockSyncWarning()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Battery Warning") {
                        ToastManager.shared.showMockBatteryWarning()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Random Warning") {
                        ToastManager.shared.showRandomWarningToast()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Info Toasts")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("Offline Mode") {
                        ToastManager.shared.showMockOfflineMode()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("New Feature") {
                        ToastManager.shared.showMockNewFeature()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Random Info") {
                        ToastManager.shared.showRandomInfoToast()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Sequence Toasts")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("Family Creation") {
                        ToastManager.shared.showFamilyCreationToasts()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Family Joining") {
                        ToastManager.shared.showFamilyJoiningToasts()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Sync Sequence") {
                        ToastManager.shared.showSyncSequenceToasts()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Divider()
            
            CopyableText(
                text: "ABC123",
                displayText: "Family Code: ABC123",
                successMessage: "🎉 Family code copied to clipboard!"
            )
            
            Button("Random Toast") {
                ToastManager.shared.showRandomMockToast()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    .withToast()
}

#Preview("Individual Toast") {
    ToastNotification(
        message: "Family created successfully! Share the code with your family members.",
        type: .success
    )
    .padding()
}