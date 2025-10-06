import SwiftUI

// MARK: - ToastView Component
struct ToastView: View {
    let message: ToastMessage
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: message.type.icon)
                .foregroundColor(message.type.color)
                .font(.system(size: 16, weight: .semibold))
            
            // Message text
            Text(message.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(message.type.color.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}

// MARK: - Toast Overlay Modifier
/// View modifier that adds toast notification overlay using proper SwiftUI binding
struct ToastOverlayModifier: ViewModifier {
    /// Using @StateObject for the singleton ToastManager to ensure proper SwiftUI binding
    @StateObject private var toastManager = ToastManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toastManager.currentToast {
                    ToastView(message: toast) {
                        toastManager.dismiss()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .zIndex(1000)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: toastManager.currentToast?.message)
    }
}

// MARK: - View Extension for Easy Integration
extension View {
    /// Adds toast notification overlay to any view
    /// - Returns: View with toast overlay capability
    func toastOverlay() -> some View {
        self.modifier(ToastOverlayModifier())
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ToastView(message: ToastMessage(message: "Run Started", type: .success)) {}
        ToastView(message: ToastMessage(message: "Stop Completed", type: .info)) {}
        ToastView(message: ToastMessage(message: "Run Paused", type: .warning)) {}
        ToastView(message: ToastMessage(message: "Run Cancelled", type: .error)) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}