//
//  TribeboardApp.swift
//  Tribeboard
//
//  Created by Tafadzwa Mawere on 2026/02/03.
//

import SwiftUI
import CoreData

@main
struct TribeboardApp: App {
    @StateObject private var dependencyContainer = DependencyContainer()
    
    var body: some Scene {
        WindowGroup {
            if AppConfig.isActiveRunOnlyMode {
                LaunchRootView()
                    .withDependencyContainer(dependencyContainer)
                    .environment(\.managedObjectContext, dependencyContainer.persistenceController.container.viewContext)
                    .environment(\.appLifecycleManager, dependencyContainer.appLifecycleManager)
                    .onAppear {
                        setupInitialConfiguration()
                    }
            } else {
                MainNavigationView(dependencyContainer: dependencyContainer)
                    .withDependencyContainer(dependencyContainer)
                    .environment(\.managedObjectContext, dependencyContainer.persistenceController.container.viewContext)
                    .environment(\.appLifecycleManager, dependencyContainer.appLifecycleManager)
                    .onAppear {
                        setupInitialConfiguration()
                    }
            }
        }
    }
    
    private func setupInitialConfiguration() {
        print("🚀 TribeBoard app launched with integrated architecture")
        
        // App lifecycle manager will handle the rest of the initialization
        Task { @MainActor in
            await dependencyContainer.appLifecycleManager.handleAppLaunch()
        }
    }
}
