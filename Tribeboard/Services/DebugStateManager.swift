//
//  DebugStateManager.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import Combine
import UIKit
import CoreLocation

/// Singleton manager for debug overlay state
/// Aggregates system state from various sources for debug display
@MainActor
class DebugStateManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DebugStateManager()
    
    // MARK: - Published Properties
    
    @Published var launchMode: LaunchMode = AppConfig.launchMode
    @Published var isDemoPlaybackEnabled: Bool = AppConfig.isDemoPlaybackEnabled
    @Published var currentUserId: String? = nil
    @Published var userMode: String = "Unknown"
    @Published var activeRunId: String? = nil
    @Published var activeRunState: RunStatus? = nil
    @Published var currentStopIndex: Int? = nil
    @Published var lastLocationUpdate: Date? = nil
    @Published var isPlaybackRunning: Bool = false
    @Published var lastPlaybackTick: Date? = nil
    @Published var playbackTickCount: Int = 0
    @Published var lastPlaybackCoordinate: CLLocationCoordinate2D? = nil
    @Published var lastObserverLocationUpdate: Date? = nil
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var debugAssertions: [DebugAssertion] = []
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationObservers()
        updateSystemState()
    }
    
    // MARK: - Public Methods
    
    /// Update playback tick information
    func updatePlaybackTick(coordinate: CLLocationCoordinate2D? = nil) {
        lastPlaybackTick = Date()
        playbackTickCount += 1
        if let coordinate = coordinate {
            lastPlaybackCoordinate = coordinate
        }
    }
    
    /// Log debug assertion with file and line information
    func logDebugAssertion(_ message: String, file: String = #file, line: Int = #line) {
        let assertion = DebugAssertion(
            message: message,
            file: URL(fileURLWithPath: file).lastPathComponent,
            line: line,
            timestamp: Date()
        )
        
        debugAssertions.append(assertion)
        
        #if DEBUG
        print("DEBUG ASSERTION: \(message) at \(assertion.file):\(line)")
        #else
        print("SAFE FALLBACK: \(message)")
        #endif
    }
    
    /// Update active run information
    func updateActiveRun(_ run: Run?) {
        activeRunId = run?.id
        activeRunState = run?.status
        currentStopIndex = run?.currentStopIndex
    }
    
    /// Update location information
    func updateLocationInfo(_ date: Date?) {
        lastLocationUpdate = date
    }
    
    /// Update playback controller status
    func updatePlaybackStatus(_ isRunning: Bool) {
        isPlaybackRunning = isRunning
    }
    
    /// Update current user information
    func updateCurrentUser(id: String?, mode: String) {
        currentUserId = id
        userMode = mode
    }
    
    /// Update observer location update time
    func updateObserverLocationUpdate(_ date: Date?) {
        lastObserverLocationUpdate = date
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        // Listen for app lifecycle changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.updateSystemState()
            }
            .store(in: &cancellables)
        
        // Listen for app configuration changes (if any)
        NotificationCenter.default.publisher(for: .debugStateChanged)
            .sink { [weak self] _ in
                self?.updateSystemState()
            }
            .store(in: &cancellables)
    }
    
    private func updateSystemState() {
        // Update configuration state
        launchMode = AppConfig.launchMode
        isDemoPlaybackEnabled = AppConfig.isDemoPlaybackEnabled
        
        // Update user information from debug mode selection
        // Requirements: 5.2, 5.4
        #if DEBUG
        if AppConfig.isActiveRunOnlyMode {
            let currentUser = AppConfig.currentDemoUser
            currentUserId = currentUser.id
            userMode = currentUser.role.displayName
        }
        #endif
        
        // Additional state updates will be handled by external services
        // calling the update methods above
    }
}

// MARK: - Supporting Types

private struct DebugAssertion {
    let message: String
    let file: String
    let line: Int
    let timestamp: Date
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let debugStateChanged = Notification.Name("debugStateChanged")
}