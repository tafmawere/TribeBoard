//
//  CalendarUtilities.swift
//  TribeBoard
//
//  Shared utility functions for calendar operations
//

import Foundation
import Combine

// MARK: - Array Extensions

extension Array {
    /// Splits the array into chunks of the specified size
    /// - Parameter size: The maximum size of each chunk
    /// - Returns: An array of arrays, where each sub-array contains at most `size` elements
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Notification posted when network status changes
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

// MARK: - NetworkMonitor Extensions

extension NetworkMonitor {
    /// Creates an AsyncStream for monitoring network status changes
    /// - Returns: AsyncStream that emits network status updates
    func networkStatusChanged() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            // Send current status immediately
            continuation.yield(isConnected)
            
            // Set up observer for future changes
            let cancellable = $isConnected
                .dropFirst() // Skip the initial value since we already sent it
                .sink { isConnected in
                    continuation.yield(isConnected)
                }
            
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
    
    /// Posts a network status change notification
    /// - Parameter isConnected: Current connection status
    func postNetworkStatusChange() {
        NotificationCenter.default.post(
            name: .networkStatusChanged,
            object: self,
            userInfo: [
                "isConnected": isConnected,
                "connectionType": connectionType,
                "isExpensive": isExpensive
            ]
        )
    }
}