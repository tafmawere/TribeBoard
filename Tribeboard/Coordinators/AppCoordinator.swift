//
//  AppCoordinator.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//
//  BACKEND CLEAN BUILD - STUB
//  This is a minimal stub for the AppCoordinator.
//  All UI navigation has been removed. This exists only for compilation.
//

import Foundation
import SwiftUI
import Combine

/// Main application coordinator - BACKEND STUB
/// All UI navigation removed in backend-only build
@MainActor
class AppCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    // MARK: - Dependencies
    
    private let dependencyContainer: DependencyContainer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        print("⚠️  AppCoordinator: Backend-only stub initialized")
    }
    
    // MARK: - Stub Methods
    
    /// Show alert with message
    func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
        print("📢 Alert: \(message)")
    }
    
    /// Handle error scenarios
    func handleError(_ error: Error, context: String = "") {
        let message = context.isEmpty ? error.localizedDescription : "\(context): \(error.localizedDescription)"
        showAlert(message: message)
    }
}