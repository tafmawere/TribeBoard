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
    VStack(spacing: 20) {
        Button("Success Toast") {
            ToastManager.shared.success("Family created successfully!")
        }
        
        Button("Error Toast") {
            ToastManager.shared.error("Failed to connect to server")
        }
        
        Button("Warning Toast") {
            ToastManager.shared.warning("Parent Admin already exists")
        }
        
        Button("Info Toast") {
            ToastManager.shared.info("Syncing family data...")
        }
        
        CopyableText(
            text: "ABC123",
            displayText: "Family Code: ABC123",
            successMessage: "Family code copied!"
        )
    }
    .padding()
    .withToast()
}

#Preview("Individual Toast") {
    ToastNotification(
        message: "Family created successfully! Share the code with your family members.",
        type: .success
    )
    .padding()
}