//
//  TribeBoardApp.swift
//  TribeBoard
//
//  Created by Tafadzwa Mawere on 2025/09/15.
//

import SwiftUI
import SwiftData

@main
struct TribeBoardApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainerConfiguration.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainNavigationView()
                .modelContainer(modelContainer)
        }
    }
}
