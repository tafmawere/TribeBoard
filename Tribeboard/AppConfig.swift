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
}

/// Single source of truth for app configuration
struct AppConfig {
    /// Current launch mode - controls app entry and navigation gating
    static let launchMode: LaunchMode = .activeRunOnly
    
    /// Enable demo playback for Active Run Only mode
    static let isDemoPlaybackEnabled: Bool = true
    
    /// Check if we're in active run only mode
    static var isActiveRunOnlyMode: Bool {
        return launchMode == .activeRunOnly
    }
    
    /// Check if full app features are available
    static var isFullAppMode: Bool {
        return launchMode == .fullApp
    }
}