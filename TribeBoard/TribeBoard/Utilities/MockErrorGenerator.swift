import Foundation
import SwiftUI

/// Comprehensive mock error generator for UI/UX prototype
/// Provides realistic error scenarios for testing error handling flows
class MockErrorGenerator: ObservableObject {
    
    // MARK: - Error Probability Configuration
    
    /// Controls how often errors occur (0.0 = never, 1.0 = always)
    @Published var errorProbability: Double = 0.0
    
    /// Enable/disable specific error categories
    @Published var enabledErrorCategories: Set<MockErrorCategory> = []
    
    /// Current error scenario being simulated  
    @Published var currentErrorScenario: MockErrorScenario?
    
    // MARK: - Error Tracking
    
    private var errorHistory: [MockErrorEvent] = []
    private var errorPatterns: [MockErrorPattern] = []
    
    // MARK: - Initialization
    
    init() {
        setupDefaultConfiguration()
    }
    
    private func setupDefaultConfiguration() {
        // Start with no errors for smooth demo experience
        errorProbability = 0.0
        enabledErrorCategories = []
    }
    
    // MARK: - Error Generation Methods
    
    /// Generate a random error based on current configuration
    func generateRandomError() -> MockError? {
        guard errorProbability > 0.0 && !enabledErrorCategories.isEmpty else {
            return nil
        }
        
        // Check if we should generate an error
        if Double.random(in: 0...1) > errorProbability {
            return nil
        }
        
        // Select random category from enabled categories
        guard let category = enabledErrorCategories.randomElement() else {
            return nil
        }
        
        return generateError(for: category)
    }
    
    /// Generate specific error for a category
    func generateError(for category: MockErrorCategory) -> MockError {
        let error: MockError
        
        switch category {
        case .authentication:
            error = generateAuthenticationError()
        case .network:
            error = generateNetworkError()
        case .validation:
            error = generateValidationError()
        case .permission:
            error = generatePermissionError()
        case .familyManagement:
            error = generateFamilyManagementError()
        case .sync:
            error = generateSyncError()
        case .qrCode:
            error = generateQRCodeError()
        case .prototype:
            error = generatePrototypeError()
        }
        
        // Track error for pattern analysis
        trackError(error)
        
        return error
    }
    
    // MARK: - Category-Specific Error Generators
    
    private func generateAuthenticationError() -> MockError {
        let authErrors: [MockError] = [
            MockError(
                id: UUID(),
                category: .authentication,
                type: .sessionExpired,
                title: "Session Expired",
                message: "Your session has expired. Please sign in again to continue using TribeBoard.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.signIn, .dismiss],
                context: ["reason": "token_expired", "lastActivity": Date().addingTimeInterval(-3600)]
            ),
            MockError(
                id: UUID(),
                category: .authentication,
                type: .accountNotFound,
                title: "Account Not Found",
                message: "We couldn't find an account with those credentials. Would you like to create a new account?",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.createAccount, .tryDifferentAccount, .dismiss],
                context: ["provider": "apple", "suggestion": "create_new"]
            ),
            MockError(
                id: UUID(),
                category: .authentication,
                type: .authenticationFailed,
                title: "Sign In Failed",
                message: "Unable to sign in with Apple ID. Please check your internet connection and try again.",
                severity: .medium,
                isRetryable: true,
                recoveryActions: [.retry, .tryDifferentMethod, .dismiss],
                context: ["provider": "apple", "error_code": "auth_failed"]
            ),
            MockError(
                id: UUID(),
                category: .authentication,
                type: .biometricFailed,
                title: "Face ID Unavailable",
                message: "Face ID authentication failed. Please use your passcode or sign in manually.",
                severity: .low,
                isRetryable: true,
                recoveryActions: [.usePasscode, .signInManually, .dismiss],
                context: ["biometric_type": "face_id", "fallback_available": true]
            )
        ]
        
        return authErrors.randomElement()!
    }
    
    private func generateNetworkError() -> MockError {
        let networkErrors: [MockError] = [
            MockError(
                id: UUID(),
                category: .network,
                type: .noConnection,
                title: "No Internet Connection",
                message: "Unable to connect to TribeBoard servers. Please check your internet connection and try again.",
                severity: .high,
                isRetryable: true,
                recoveryActions: [.checkConnection, .workOffline, .retry, .dismiss],
                context: ["connection_type": "none", "offline_mode_available": true]
            ),
            MockError(
                id: UUID(),
                category: .network,
                type: .slowConnection,
                title: "Slow Connection",
                message: "Your internet connection is slow. Some features may take longer to load.",
                severity: .low,
                isRetryable: false,
                recoveryActions: [.continueAnyway, .workOffline, .dismiss],
                context: ["connection_speed": "slow", "estimated_time": "30s"]
            ),
            MockError(
                id: UUID(),
                category: .network,
                type: .serverUnavailable,
                title: "Server Unavailable",
                message: "TribeBoard servers are temporarily unavailable. Please try again in a few minutes.",
                severity: .high,
                isRetryable: true,
                recoveryActions: [.retry, .workOffline, .checkStatus, .dismiss],
                context: ["server_status": "maintenance", "estimated_recovery": "5 minutes"]
            ),
            MockError(
                id: UUID(),
                category: .network,
                type: .timeout,
                title: "Connection Timeout",
                message: "The request took too long to complete. Please check your connection and try again.",
                severity: .medium,
                isRetryable: true,
                recoveryActions: [.retry, .checkConnection, .dismiss],
                context: ["timeout_duration": "30s", "retry_recommended": true]
            )
        ]
        
        return networkErrors.randomElement()!
    }
    
    private func generateValidationError() -> MockError {
        let validationErrors: [MockError] = [
            MockError(
                id: UUID(),
                category: .validation,
                type: .invalidInput,
                title: "Invalid Family Name",
                message: "Family name must be at least 2 characters and contain only letters, numbers, and spaces.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.editInput, .dismiss],
                context: ["field": "family_name", "min_length": 2, "current_length": 1]
            ),
            MockError(
                id: UUID(),
                category: .validation,
                type: .duplicateData,
                title: "Family Name Already Exists",
                message: "A family with the name 'Mawere Family' already exists. Please choose a different name.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.chooseDifferentName, .addSuffix, .dismiss],
                context: ["existing_name": "Mawere Family", "suggestions": ["Mawere Family 2", "The Mawere Family"]]
            ),
            MockError(
                id: UUID(),
                category: .validation,
                type: .invalidFormat,
                title: "Invalid Family Code",
                message: "Family code must be 6-8 characters containing only letters and numbers.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.generateNewCode, .editCode, .dismiss],
                context: ["code_format": "alphanumeric", "length_range": "6-8", "current_code": "ABC-123"]
            )
        ]
        
        return validationErrors.randomElement()!
    }
    
    private func generatePermissionError() -> MockError {
        let permissionErrors: [MockError] = [
            MockError(
                id: UUID(),
                category: .permission,
                type: .accessDenied,
                title: "Access Denied",
                message: "You don't have permission to perform this action. Only family admins can manage members and settings.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.contactAdmin, .requestPermission, .dismiss],
                context: ["required_role": "admin", "current_role": "member", "admin_contact": "sarah@example.com"]
            ),
            MockError(
                id: UUID(),
                category: .permission,
                type: .childRestriction,
                title: "Parental Permission Required",
                message: "This feature requires parental permission. We'll send a request to your parents for approval.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.requestPermission, .askParent, .dismiss],
                context: ["feature": "location_sharing", "parent_contacts": ["mom", "dad"]]
            ),
            MockError(
                id: UUID(),
                category: .permission,
                type: .cameraPermission,
                title: "Camera Access Needed",
                message: "TribeBoard needs camera access to scan QR codes. Please enable camera permission in Settings.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.openSettings, .enterCodeManually, .dismiss],
                context: ["permission_type": "camera", "feature": "qr_scanning", "alternative_available": true]
            )
        ]
        
        return permissionErrors.randomElement()!
    }
    
    private func generateFamilyManagementError() -> MockError {
        let familyErrors: [MockError] = [
            MockError(
                id: UUID(),
                category: .familyManagement,
                type: .familyNotFound,
                title: "Family Not Found",
                message: "The family code 'ABC123' doesn't exist. Please check the code and try again.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.tryDifferentCode, .scanQRCode, .contactSender, .dismiss],
                context: ["entered_code": "ABC123", "suggestion": "double_check_code"]
            ),
            MockError(
                id: UUID(),
                category: .familyManagement,
                type: .familyFull,
                title: "Family is Full",
                message: "This family has reached its maximum of 8 members. Contact the family admin to make space.",
                severity: .high,
                isRetryable: false,
                recoveryActions: [.contactAdmin, .waitForSpace, .dismiss],
                context: ["max_members": 8, "current_members": 8, "admin_contact": "sarah@example.com"]
            ),
            MockError(
                id: UUID(),
                category: .familyManagement,
                type: .alreadyMember,
                title: "Already in Family",
                message: "You're already a member of the 'Mawere Family'. You can only be in one family at a time.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.switchFamilies, .stayInCurrent, .dismiss],
                context: ["current_family": "Mawere Family", "new_family": "Smith Family"]
            )
        ]
        
        return familyErrors.randomElement()!
    }
    
    private func generateSyncError() -> MockError {
        let syncErrors: [MockError] = [
            MockError(
                id: UUID(),
                category: .sync,
                type: .syncFailed,
                title: "Sync Failed",
                message: "Some changes couldn't be synced to iCloud. Your data is safe locally and will sync when connection improves.",
                severity: .low,
                isRetryable: true,
                recoveryActions: [.forceSync, .continueOffline, .checkConnection, .dismiss],
                context: ["pending_changes": 3, "last_sync": Date().addingTimeInterval(-300)]
            ),
            MockError(
                id: UUID(),
                category: .sync,
                type: .conflictDetected,
                title: "Sync Conflict",
                message: "Your family data was modified on another device. We've merged the changes automatically.",
                severity: .low,
                isRetryable: false,
                recoveryActions: [.reviewChanges, .acceptMerge, .dismiss],
                context: ["conflict_type": "member_added", "other_device": "Sarah's iPhone", "resolution": "automatic"]
            ),
            MockError(
                id: UUID(),
                category: .sync,
                type: .quotaExceeded,
                title: "iCloud Storage Full",
                message: "Your iCloud storage is full. Family data will only be saved locally until you free up space.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.manageStorage, .upgradeStorage, .continueLocal, .dismiss],
                context: ["storage_used": "5GB", "storage_limit": "5GB", "upgrade_available": true]
            )
        ]
        
        return syncErrors.randomElement()!
    }
    
    private func generateQRCodeError() -> MockError {
        let qrErrors: [MockError] = [
            MockError(
                id: UUID(),
                category: .qrCode,
                type: .scanFailed,
                title: "QR Code Not Recognized",
                message: "The QR code couldn't be read or isn't a valid TribeBoard family code. Make sure the code is clear and well-lit.",
                severity: .medium,
                isRetryable: true,
                recoveryActions: [.tryAgain, .enterCodeManually, .improveLight, .dismiss],
                context: ["scan_attempts": 3, "light_level": "low", "manual_entry_available": true]
            ),
            MockError(
                id: UUID(),
                category: .qrCode,
                type: .invalidQRCode,
                title: "Invalid QR Code",
                message: "This QR code is not from TribeBoard. Please scan a TribeBoard family invitation code.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.scanDifferentCode, .enterCodeManually, .getNewCode, .dismiss],
                context: ["qr_type": "unknown", "expected_format": "TRIBEBOARD://join/"]
            )
        ]
        
        return qrErrors.randomElement()!
    }
    
    private func generatePrototypeError() -> MockError {
        let prototypeErrors: [MockError] = [
            MockError(
                id: UUID(),
                category: .prototype,
                type: .featurePreview,
                title: "Feature Preview",
                message: "Video calling is available in the full version. This prototype shows the interface design and user flow.",
                severity: .info,
                isRetryable: false,
                recoveryActions: [.learnMore, .continueDemo, .dismiss],
                context: ["feature_name": "Video Calling", "availability": "full_version"]
            ),
            MockError(
                id: UUID(),
                category: .prototype,
                type: .dataLimit,
                title: "Demo Data Limit",
                message: "You've reached the demo data limit. In the full app, you can add unlimited family members and content.",
                severity: .info,
                isRetryable: false,
                recoveryActions: [.continueDemo, .resetDemo, .learnMore, .dismiss],
                context: ["limit_type": "members", "current_count": 8, "full_version_limit": "unlimited"]
            )
        ]
        
        return prototypeErrors.randomElement()!
    }
    
    // MARK: - Error Scenario Management
    
    /// Start a specific error scenario for testing
    func startErrorScenario(_ scenario: MockErrorScenario) {
        currentErrorScenario = scenario
        
        switch scenario {
        case .networkOutage:
            enabledErrorCategories = [.network]
            errorProbability = 0.8
        case .networkError:
            enabledErrorCategories = [.network]
            errorProbability = 0.7
        case .authenticationIssues:
            enabledErrorCategories = [.authentication]
            errorProbability = 0.6
        case .authenticationError:
            enabledErrorCategories = [.authentication]
            errorProbability = 0.5
        case .validationProblems:
            enabledErrorCategories = [.validation]
            errorProbability = 0.7
        case .permissionDenials:
            enabledErrorCategories = [.permission]
            errorProbability = 0.5
        case .syncConflicts:
            enabledErrorCategories = [.sync]
            errorProbability = 0.4
        case .syncConflict:
            enabledErrorCategories = [.sync]
            errorProbability = 0.3
        case .mixedErrors:
            enabledErrorCategories = [.network, .validation, .sync, .permission]
            errorProbability = 0.3
        case .prototypeDemo:
            enabledErrorCategories = [.prototype]
            errorProbability = 0.2
        }
    }
    
    /// Stop current error scenario
    func stopErrorScenario() {
        currentErrorScenario = nil
        enabledErrorCategories = []
        errorProbability = 0.0
    }
    
    // MARK: - Error Tracking and Analytics
    
    private func trackError(_ error: MockError) {
        let event = MockErrorEvent(
            error: error,
            timestamp: Date(),
            context: getCurrentContext()
        )
        
        errorHistory.append(event)
        
        // Keep only recent errors (last 100)
        if errorHistory.count > 100 {
            errorHistory.removeFirst(errorHistory.count - 100)
        }
        
        // Analyze patterns
        analyzeErrorPatterns()
    }
    
    private func getCurrentContext() -> [String: Any] {
        return [
            "app_state": "active",
            "network_status": "connected",
            "user_authenticated": true,
            "current_view": "unknown"
        ]
    }
    
    private func analyzeErrorPatterns() {
        // Simple pattern detection
        let recentErrors = Array(errorHistory.suffix(5))
        
        if recentErrors.count >= 3 {
            let categories = recentErrors.map { $0.error.category }
            
            // Check for repeated category
            if let mostCommon = mostFrequent(in: categories),
               categories.filter({ $0 == mostCommon }).count >= 3 {
                
                let pattern = MockErrorPattern(
                    type: .repeatedCategory(mostCommon),
                    frequency: categories.filter({ $0 == mostCommon }).count,
                    timespan: recentErrors.last!.timestamp.timeIntervalSince(recentErrors.first!.timestamp),
                    recommendation: getRecommendation(for: mostCommon)
                )
                
                errorPatterns.append(pattern)
            }
        }
    }
    
    private func mostFrequent<T: Hashable>(in array: [T]) -> T? {
        let counts = array.reduce(into: [:]) { counts, item in
            counts[item, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    private func getRecommendation(for category: MockErrorCategory) -> String {
        switch category {
        case .network:
            return "Check internet connection and consider offline mode"
        case .authentication:
            return "Review authentication flow and session management"
        case .validation:
            return "Improve input validation and user guidance"
        case .permission:
            return "Clarify permission requirements and provide alternatives"
        case .familyManagement:
            return "Simplify family joining process and improve error messages"
        case .sync:
            return "Implement better conflict resolution and offline support"
        case .qrCode:
            return "Improve QR scanning conditions and provide manual alternatives"
        case .prototype:
            return "Clearly communicate prototype limitations"
        }
    }
    
    // MARK: - Demo and Testing Methods
    
    /// Generate a series of errors for demo purposes
    func generateDemoErrorSequence() -> [MockError] {
        let sequence: [MockError] = [
            generateError(for: .network),
            generateError(for: .authentication),
            generateError(for: .validation),
            generateError(for: .permission),
            generateError(for: .familyManagement),
            generateError(for: .sync),
            generateError(for: .qrCode),
            generateError(for: .prototype)
        ]
        
        return sequence
    }
    
    /// Get error statistics for analytics
    func getErrorStatistics() -> MockErrorStatistics {
        let categoryCount = Dictionary(grouping: errorHistory, by: { $0.error.category })
            .mapValues { $0.count }
        
        let severityCount = Dictionary(grouping: errorHistory, by: { $0.error.severity })
            .mapValues { $0.count }
        
        return MockErrorStatistics(
            totalErrors: errorHistory.count,
            errorsByCategory: categoryCount,
            errorsBySeverity: severityCount,
            patterns: errorPatterns,
            averageErrorsPerHour: calculateAverageErrorsPerHour()
        )
    }
    
    private func calculateAverageErrorsPerHour() -> Double {
        guard !errorHistory.isEmpty else { return 0.0 }
        
        let timespan = Date().timeIntervalSince(errorHistory.first!.timestamp)
        let hours = timespan / 3600.0
        
        return hours > 0 ? Double(errorHistory.count) / hours : 0.0
    }
    
    /// Reset error tracking
    func resetErrorTracking() {
        errorHistory.removeAll()
        errorPatterns.removeAll()
        currentErrorScenario = nil
        errorProbability = 0.0
        enabledErrorCategories.removeAll()
    }
}