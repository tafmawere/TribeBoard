import SwiftUI

// MARK: - ToastView Component
struct ToastView: View {
    let message: ToastData
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
struct ToastOverlayModifier: ViewModifier {
    @ObservedObject var toastManager: ToastManager
    
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
    /// - Parameter toastManager: The ToastManager instance to observe
    /// - Returns: View with toast overlay capability
    func toastOverlay(_ toastManager: ToastManager) -> some View {
        self.modifier(ToastOverlayModifier(toastManager: toastManager))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ToastView(message: ToastData(message: "Run Started", type: .success, duration: 3.0)) {}
        ToastView(message: ToastData(message: "Stop Completed", type: .info, duration: 3.0)) {}
        ToastView(message: ToastData(message: "Run Paused", type: .warning, duration: 3.0)) {}
        ToastView(message: ToastData(message: "Run Cancelled", type: .error, duration: 3.0)) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}