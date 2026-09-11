import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected: Bool = true
    
    var onReconnect: (() -> Void)?
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "tribeboard.network.monitor")
    
    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                if !wasConnected && self.isConnected {
                    self.onReconnect?()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

