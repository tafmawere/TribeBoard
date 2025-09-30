import SwiftUI

/// A retry button that intelligently handles network connectivity
struct NetworkAwareRetryButton: View {
    
    // MARK: - Properties
    
    let title: String
    let onRetry: () async -> Void
    let isLoading: Bool
    
    // MARK: - State
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var isWaitingForNetwork = false
    
    // MARK: - Initialization
    
    init(
        title: String = "Retry",
        isLoading: Bool = false,
        onRetry: @escaping () async -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.onRetry = onRetry
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            Task {
                await handleRetry()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading || isWaitingForNetwork {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                }
                
                Text(buttonTitle)
                    .font(DesignSystem.Typography.labelMedium)
            }
        }
        .disabled(isLoading || isWaitingForNetwork)
        .foregroundColor(buttonColor)
        .animation(DesignSystem.Animation.standard, value: isWaitingForNetwork)
        .animation(DesignSystem.Animation.standard, value: networkMonitor.isConnected)
    }
    
    // MARK: - Computed Properties
    
    private var buttonTitle: String {
        if isWaitingForNetwork {
            return "Waiting for connection..."
        } else if isLoading {
            return "Retrying..."
        } else if !networkMonitor.isConnected {
            return "Connect to retry"
        } else {
            return title
        }
    }
    
    private var buttonColor: Color {
        if !networkMonitor.isConnected {
            return .secondary
        } else {
            return .brandPrimary
        }
    }
    
    // MARK: - Actions
    
    private func handleRetry() async {
        if !networkMonitor.isConnected {
            // Wait for network connection before retrying
            isWaitingForNetwork = true
            
            let connected = await networkMonitor.waitForConnection(timeout: 30.0)
            
            isWaitingForNetwork = false
            
            if connected {
                await onRetry()
            }
        } else {
            await onRetry()
        }
    }
}

// MARK: - Preview

#Preview("Network Aware Retry - Connected") {
    VStack {
        NetworkAwareRetryButton(
            title: "Try Again",
            isLoading: false
        ) {
            print("Retry action")
        }
        .padding()
    }
    .onAppear {
        NetworkMonitor.shared.isConnected = true
    }
}

#Preview("Network Aware Retry - Disconnected") {
    VStack {
        NetworkAwareRetryButton(
            title: "Try Again",
            isLoading: false
        ) {
            print("Retry action")
        }
        .padding()
    }
    .onAppear {
        NetworkMonitor.shared.isConnected = false
    }
}

#Preview("Network Aware Retry - Loading") {
    VStack {
        NetworkAwareRetryButton(
            title: "Try Again",
            isLoading: true
        ) {
            print("Retry action")
        }
        .padding()
    }
}