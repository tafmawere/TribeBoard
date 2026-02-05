//
//  AppConfig.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation

/// Application configuration for launch modes
/// Controls which features are available in the app
enum LaunchMode {
    case activeRunOnly
    case fullApp
    case demoFlow
}

/// User mode for debug scenarios
/// Only available in DEBUG builds for testing different user perspectives
enum UserMode {
    case driver
    case observer
}

/// Single source of truth for app configuration
struct AppConfig {
    /// Current launch mode - controls app entry and navigation gating
    #if DEBUG
    static var launchMode: LaunchMode = .demoFlow
    #else
    static let launchMode: LaunchMode = .activeRunOnly
    #endif
    
    /// Enable demo playback for Active Run Only mode
    static let isDemoPlaybackEnabled: Bool = true
    
    #if DEBUG
    /// Debug user mode toggle - only available in DEBUG builds
    /// Allows switching between driver and observer perspectives for testing
    /// Requirements: 5.1, 5.3
    static var demoCurrentUserMode: UserMode = .driver
    
    /// Demo user selection for full app testing
    enum DemoUser {
        case rue
        case tafadzwa
    }
    
    /// Current demo user for full app mode testing
    static var demoUser: DemoUser = .rue
    #endif
    
    /// Check if we're in active run only mode
    static var isActiveRunOnlyMode: Bool {
        return launchMode == .activeRunOnly
    }
    
    /// Check if full app features are available
    static var isFullAppMode: Bool {
        return launchMode == .fullApp
    }
    
    /// Check if demo flow mode is enabled
    static var isDemoFlowEnabled: Bool {
        return launchMode == .demoFlow
    }
    
    /// Get current demo user based on debug mode selection
    /// In DEBUG builds, uses demoCurrentUserMode to determine user
    /// In Release builds, returns the actual current user
    /// Requirements: 5.1, 5.3
    static var currentDemoUser: User {
        #if DEBUG
        switch demoCurrentUserMode {
        case .driver:
            return User(
                id: "demo_driver_user_id",
                displayName: "Demo Driver",
                role: .driver,
                familyId: "demo_family_id"
            )
        case .observer:
            return User(
                id: "demo_observer_user_id", 
                displayName: "Demo Observer",
                role: .observer,
                familyId: "demo_family_id"
            )
        }
        #else
        // In Release builds, this should return the actual current user
        // For now, return driver as default - this would be replaced with actual user logic
        return User(
            id: "demo_driver_user_id",
            displayName: "Demo Driver", 
            role: .driver,
            familyId: "demo_family_id"
        )
        #endif
    }
}