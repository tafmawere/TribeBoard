//
//  TribeBoardApp.swift
//  TribeBoard
//
//  Created by Tafadzwa Mawere on 2025/09/15.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct TribeBoardApp: App {
    let modelContainer: ModelContainer
    @StateObject private var cloudKitService = CloudKitService()
    @StateObject private var authService = AuthService()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        do {
            // Validate SwiftData schema before creating container
            print("🔍 Validating SwiftData schema...")
            try ModelContainerConfiguration.validateSchema()
            
            // Use the fallback method that gracefully handles CloudKit failures
            modelContainer = ModelContainerConfiguration.createWithFallback()
            print("✅ TribeBoardApp initialized with ModelContainer")
        } catch {
            print("💥 CRITICAL: Failed to initialize ModelContainer: \(error)")
            print("   This indicates a fundamental issue with SwiftData model definitions")
            
            // Last resort: try to create a minimal in-memory container
            do {
                modelContainer = try ModelContainerConfiguration.createInMemory()
                print("⚠️ Using emergency in-memory container - data will not persist")
            } catch {
                fatalError("Unable to create any ModelContainer. Check SwiftData model definitions: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            AppLaunchView(
                modelContainer: modelContainer,
                cloudKitService: cloudKitService,
                authService: authService
            )
        }
    }
}

// MARK: - Custom Notification Names

extension Notification.Name {
    static let didReceiveRemoteNotificationNotification = Notification.Name("didReceiveRemoteNotification")
}

// MARK: - UIApplication Extension for Remote Notifications

extension UIApplication {
    static func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .didReceiveRemoteNotificationNotification,
            object: nil,
            userInfo: userInfo
        )
    }
}

// MARK: - App Launch View

struct AppLaunchView: View {
    let modelContainer: ModelContainer
    let cloudKitService: CloudKitService
    let authService: AuthService
    
    @State private var isInitializing = true
    @State private var initializationMessage = "Starting TribeBoard..."
    
    var body: some View {
        ZStack {
            if isInitializing {
                AnimatedSplashScreenView(message: initializationMessage)
                    .transition(.opacity)
            } else {
                AuthenticationStateView()
                    .modelContainer(modelContainer)
                    .environmentObject(cloudKitService)
                    .environmentObject(authService)
                    .transition(.opacity)
            }
        }
        .onAppear {
            initializeApp()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didFinishLaunchingNotification)) { _ in
            UIApplication.shared.registerForRemoteNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveRemoteNotificationNotification)) { notification in
            if let userInfo = notification.userInfo {
                Task {
                    await cloudKitService.handleRemoteNotification(userInfo)
                }
            }
        }
    }
    
    private func initializeApp() {
        Task {
            let minimumSplashDuration: TimeInterval = 3.0
            let startTime = Date()
            
            // Setup CloudKit
            await MainActor.run {
                initializationMessage = "Connecting to iCloud..."
            }
            
            await setupCloudKit()
            
            // Setup authentication service
            await MainActor.run {
                initializationMessage = "Setting up authentication..."
            }
            
            await setupAuthService()
            
            // Request notification permissions
            await MainActor.run {
                initializationMessage = "Setting up notifications..."
            }
            
            await requestNotificationPermissions()
            
            // Final setup
            await MainActor.run {
                initializationMessage = "Almost ready..."
            }
            
            // Ensure minimum splash duration
            let elapsedTime = Date().timeIntervalSince(startTime)
            let remainingTime = max(0, minimumSplashDuration - elapsedTime)
            
            if remainingTime > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
            }
            
            // Hide splash screen
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.6)) {
                    isInitializing = false
                }
            }
        }
    }
    
    // MARK: - CloudKit Setup
    
    @MainActor
    private func setupCloudKit() async {
        do {
            try await cloudKitService.performInitialSetup()
            print("CloudKit setup completed successfully")
        } catch {
            print("CloudKit setup failed: \(error)")
            // Continue without CloudKit - app should work offline
        }
    }
    
    // MARK: - Authentication Setup
    
    @MainActor
    private func setupAuthService() async {
        do {
            // Create a DataService with the model context for the AuthService
            let dataService = DataService(modelContext: modelContainer.mainContext)
            authService.setDataService(dataService)
            
            // Check for existing authentication after setting up the data service
            await authService.checkExistingAuthentication()
            
            print("AuthService setup completed successfully")
        } catch {
            print("AuthService setup failed: \(error)")
            // Continue without authentication - user will need to sign in manually
        }
    }
    
    // MARK: - Notification Permissions
    
    private func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                print("Notification permissions granted")
            } else {
                print("Notification permissions denied")
            }
        } catch {
            print("Failed to request notification permissions: \(error)")
        }
    }
}
