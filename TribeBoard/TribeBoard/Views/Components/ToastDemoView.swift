import SwiftUI

// MARK: - Toast Demo View for Testing
/// Demo view for testing toast notifications with proper SwiftUI binding
struct ToastDemoView: View {
    /// Using @StateObject for the singleton ToastManager to ensure proper SwiftUI binding
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
                        toastManager.success("Run Started")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    // Info Toast
                    Button("Show Info Toast") {
                        toastManager.info("Stop Completed")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                    // Warning Toast
                    Button("Show Warning Toast") {
                        toastManager.warning("Run Paused")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    // Error Toast
                    Button("Show Error Toast") {
                        toastManager.error("Run Cancelled")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    // Long message test
                    Button("Show Long Message") {
                        toastManager.info("This is a longer toast message to test how the component handles multiple lines of text")
                    }
                    .buttonStyle(.bordered)
                    
                    // Manual dismiss test
                    Button("Show Persistent Toast") {
                        toastManager.info("This toast won't auto-dismiss")
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
        .withToast()
    }
}

// MARK: - Preview
#Preview {
    ToastDemoView()
}