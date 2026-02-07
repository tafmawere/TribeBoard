//
//  SettingsPlaceholderView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Placeholder settings screen for demo
struct SettingsPlaceholderView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    
    var body: some View {
        NavigationView {
            List {
                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Demo)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Launch Mode")
                        Spacer()
                        Text(launchMode)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Current User")
                        Spacer()
                        Text(currentUserName)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Demo Settings") {
                    Text("Settings features coming soon")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private var launchMode: String {
        if AppConfig.isActiveRunOnlyMode {
            return "Active Run Only"
        } else if AppConfig.isDemoFlowEnabled {
            return "Demo Flow"
        } else {
            return "Full App"
        }
    }
    
    private var currentUserName: String {
        let userId = dependencyContainer.roleManagementService.currentUserId
        switch userId {
        case DemoSeedDataService.rueId:
            return "Rue Mawere"
        case DemoSeedDataService.tafadzwaId:
            return "Tafadzwa Mawere"
        case DemoSeedDataService.tjId:
            return "TJ"
        case DemoSeedDataService.tawanaId:
            return "Tawana"
        default:
            return "Unknown"
        }
    }
}
