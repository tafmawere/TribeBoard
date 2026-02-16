//
//  TribeboardApp.swift
//  Tribeboard
//
//  Created by Tafadzwa Mawere on 2026/02/03.
//
//  BACKEND CLEAN BUILD
//  This is a minimal placeholder entry point for the backend-only codebase.
//  All UI screens have been removed. This file exists only to ensure the project compiles.
//

import SwiftUI
import CoreData

@main
struct TribeboardApp: App {
    @StateObject private var dependencyContainer = DependencyContainer()
    
    var body: some Scene {
        WindowGroup {
            BackendCleanPlaceholderView()
                .environment(\.managedObjectContext, dependencyContainer.persistenceController.container.viewContext)
                .onAppear {
                    setupBackendServices()
                }
        }
    }
    
    private func setupBackendServices() {
        print("🔧 Backend Clean Build - Services Initialized")
        print("📦 Available Services:")
        print("   - RunEventService")
        print("   - RunStateMachine")
        print("   - RoleManagementService")
        print("   - RoleBasedDataFilter")
        print("   - MockFirebaseService")
        print("   - LocationService")
        print("   - OfflineSyncService")
        print("   - ErrorHandlingService")
        print("   - DemoSeedDataService")
        print("   - Scheduling Services")
        print("")
        print("ℹ️  This is a backend-only build. All UI screens have been removed.")
        print("ℹ️  Use this codebase as a framework/SDK for frontend implementations.")
        
        // Initialize backend services without UI
        Task { @MainActor in
            await dependencyContainer.appLifecycleManager.handleAppLaunch()
        }
    }
}

// MARK: - Minimal Placeholder View

struct BackendCleanPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Backend Clean Build")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Tribeboard Backend Services")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.horizontal, 40)
            
            VStack(alignment: .leading, spacing: 12) {
                ServiceRow(icon: "gearshape.2", name: "Run State Management")
                ServiceRow(icon: "person.3", name: "Role-Based Access Control")
                ServiceRow(icon: "arrow.triangle.2.circlepath", name: "Real-Time Sync")
                ServiceRow(icon: "calendar", name: "Scheduling Engine")
                ServiceRow(icon: "location", name: "Location Services")
                ServiceRow(icon: "icloud", name: "Offline Sync")
            }
            .padding()
            
            Spacer()
            
            Text("All UI screens removed")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Use as framework/SDK for frontend implementations")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .padding()
    }
}

struct ServiceRow: View {
    let icon: String
    let name: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            Text(name)
                .font(.body)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}
