import SwiftUI

// MARK: - Toast Demo View for Testing
struct ToastDemoView: View {
    @StateObject private var toastManager = ToastManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Toast Notification Demo")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.bottom, 20)
                
                VStack(spacing: 16) {
                    // Success Toast
                    Button("Show Success Toast") {
                        toastManager.show(message: "Run Started", type: .success)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    // Info Toast
                    Button("Show Info Toast") {
                        toastManager.show(message: "Stop Completed", type: .info)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                    // Warning Toast
                    Button("Show Warning Toast") {
                        toastManager.show(message: "Run Paused", type: .warning)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    // Error Toast
                    Button("Show Error Toast") {
                        toastManager.show(message: "Run Cancelled", type: .error)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    // Long message test
                    Button("Show Long Message") {
                        toastManager.show(message: "This is a longer toast message to test how the component handles multiple lines of text", type: .info)
                    }
                    .buttonStyle(.bordered)
                    
                    // Manual dismiss test
                    Button("Show Persistent Toast") {
                        toastManager.show(message: "This toast won't auto-dismiss", type: .info)
                        // Cancel auto-dismiss for testing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Keep the toast visible for manual testing
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Toast Demo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .toastOverlay(toastManager)
    }
}

// MARK: - Preview
#Preview {
    ToastDemoView()
}