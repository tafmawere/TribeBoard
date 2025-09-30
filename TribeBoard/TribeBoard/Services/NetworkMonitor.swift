import Foundation
import Network
import Combine

/// Service for monitoring network connectivity status
@MainActor
class NetworkMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current network connectivity status
    @Published var isConnected: Bool = true
    
    /// Current network path status
    @Published var connectionType: ConnectionType = .unknown
    
    /// Whether the network is expensive (cellular data)
    @Published var isExpensive: Bool = false
    
    // MARK: - Types
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        
        var displayName: String {
            switch self {
            case .wifi:
                return "Wi-Fi"
            case .cellular:
                return "Cellular"
            case .ethernet:
                return "Ethernet"
            case .unknown:
                return "Unknown"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Initialization
    
    init() {
        startMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Check if network is available for authentication operations
    /// - Returns: True if network is available and suitable for authentication
    func isNetworkAvailableForAuth() -> Bool {
        return isConnected
    }
    
    /// Get user-friendly network status message
    /// - Returns: String describing current network status
    func getNetworkStatusMessage() -> String {
        if isConnected {
            let typeMessage = connectionType != .unknown ? " via \(connectionType.displayName)" : ""
            let expensiveMessage = isExpensive ? " (using cellular data)" : ""
            return "Connected\(typeMessage)\(expensiveMessage)"
        } else {
            return "No internet connection"
        }
    }
    
    /// Wait for network connection to become available
    /// - Parameter timeout: Maximum time to wait in seconds
    /// - Returns: True if connection became available within timeout
    func waitForConnection(timeout: TimeInterval = 10.0) async -> Bool {
        if isConnected {
            return true
        }
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            // Set up timeout
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: false)
                }
            }
            
            // Set up connection observer
            let cancellable = $isConnected
                .filter { $0 } // Only when connected becomes true
                .first()
                .sink { _ in
                    if !hasResumed {
                        hasResumed = true
                        timeoutTask.cancel()
                        continuation.resume(returning: true)
                    }
                }
            
            // Clean up cancellable when task completes
            Task {
                _ = await timeoutTask.result
                cancellable.cancel()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateNetworkStatus(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
    
    private func updateNetworkStatus(_ path: NWPath) {
        // Update connection status
        isConnected = path.status == .satisfied
        
        // Update connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
        
        // Update expensive status
        isExpensive = path.isExpensive
    }
}

// MARK: - Singleton Access

extension NetworkMonitor {
    /// Shared instance for app-wide network monitoring
    static let shared = NetworkMonitor()
}