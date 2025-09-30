import SwiftUI

/// Component that displays network connectivity status and provides retry options
struct NetworkStatusView: View {
    
    // MARK: - Environment
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    // MARK: - Properties
    
    let onRetry: (() -> Void)?
    let showWhenConnected: Bool
    
    // MARK: - Initialization
    
    init(onRetry: (() -> Void)? = nil, showWhenConnected: Bool = false) {
        self.onRetry = onRetry
        self.showWhenConnected = showWhenConnected
    }
    
    // MARK: - Body
    
    var body: some View {
        if !networkMonitor.isConnected || showWhenConnected {
            networkStatusCard
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
        }
    }
    
    // MARK: - Network Status Card
    
    private var networkStatusCard: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Status icon
            statusIcon
            
            // Status message
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                
                Text(networkMonitor.getNetworkStatusMessage())
                    .font(DesignSystem.Typography.captionLarge)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Retry button for disconnected state
            if !networkMonitor.isConnected, let onRetry = onRetry {
                Button("Retry") {
                    onRetry()
                }
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(.brandPrimary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(backgroundColor)
        .cornerRadius(BrandStyle.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .animation(DesignSystem.Animation.standard, value: networkMonitor.isConnected)
    }
    
    // MARK: - Status Components
    
    private var statusIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(statusColor)
            .frame(width: 20, height: 20)
    }
    
    // MARK: - Computed Properties
    
    private var statusTitle: String {
        if networkMonitor.isConnected {
            return "Connected"
        } else {
            return "No Internet Connection"
        }
    }
    
    private var statusColor: Color {
        if networkMonitor.isConnected {
            return .green
        } else {
            return .orange
        }
    }
    
    private var backgroundColor: Color {
        if networkMonitor.isConnected {
            return .green.opacity(0.1)
        } else {
            return .orange.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        if networkMonitor.isConnected {
            return .green.opacity(0.3)
        } else {
            return .orange.opacity(0.3)
        }
    }
    
    private var iconName: String {
        if networkMonitor.isConnected {
            switch networkMonitor.connectionType {
            case .wifi:
                return "wifi"
            case .cellular:
                return "antenna.radiowaves.left.and.right"
            case .ethernet:
                return "cable.connector"
            case .unknown:
                return "network"
            }
        } else {
            return "wifi.slash"
        }
    }
}

// MARK: - Network Status Banner

/// A banner-style network status view that appears at the top of screens
struct NetworkStatusBanner: View {
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    let onRetry: (() -> Void)?
    
    init(onRetry: (() -> Void)? = nil) {
        self.onRetry = onRetry
    }
    
    var body: some View {
        if !networkMonitor.isConnected {
            VStack(spacing: 0) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("No Internet Connection")
                        .font(DesignSystem.Typography.captionLarge)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if let onRetry = onRetry {
                        Button("Retry") {
                            onRetry()
                        }
                        .font(DesignSystem.Typography.captionLarge)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(Color.orange)
                
                Divider()
                    .background(Color.orange.opacity(0.3))
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top),
                removal: .move(edge: .top)
            ))
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Adds a network status banner to the top of the view
    /// - Parameter onRetry: Optional closure to execute when user taps retry
    func networkStatusBanner(onRetry: (() -> Void)? = nil) -> some View {
        VStack(spacing: 0) {
            NetworkStatusBanner(onRetry: onRetry)
            self
        }
    }
    
    /// Adds a network status card overlay to the view
    /// - Parameters:
    ///   - onRetry: Optional closure to execute when user taps retry
    ///   - showWhenConnected: Whether to show the status when connected
    func networkStatusOverlay(
        onRetry: (() -> Void)? = nil,
        showWhenConnected: Bool = false
    ) -> some View {
        ZStack(alignment: .top) {
            self
            
            NetworkStatusView(
                onRetry: onRetry,
                showWhenConnected: showWhenConnected
            )
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.sm)
        }
    }
}

// MARK: - Preview

#Preview("Network Status - Connected") {
    VStack {
        NetworkStatusView(showWhenConnected: true)
            .padding()
        
        Spacer()
    }
    .onAppear {
        NetworkMonitor.shared.isConnected = true
        NetworkMonitor.shared.connectionType = .wifi
    }
}

#Preview("Network Status - Disconnected") {
    VStack {
        NetworkStatusView(onRetry: {
            print("Retry tapped")
        })
        .padding()
        
        Spacer()
    }
    .onAppear {
        NetworkMonitor.shared.isConnected = false
    }
}

#Preview("Network Status Banner") {
    VStack {
        Text("Main Content")
            .padding()
        Spacer()
    }
    .networkStatusBanner(onRetry: {
        print("Banner retry tapped")
    })
    .onAppear {
        NetworkMonitor.shared.isConnected = false
    }
}