import SwiftUI

// MARK: - Preview Environment Helpers

extension View {
    func legacyPreviewEnvironment(_ environment: PreviewEnvironment) -> some View {
        self.environmentObject(AppState.preview(for: environment))
    }
}

enum PreviewEnvironment {
    case authenticated
    case unauthenticated
    case loading
    case error
}

extension AppState {
    static func preview(for environment: PreviewEnvironment) -> AppState {
        let appState = AppState()
        
        switch environment {
        case .authenticated:
            // Set up authenticated state
            appState.currentUser = UserProfile(
                displayName: "Preview User",
                appleUserIdHash: "preview_hash_123"
            )
        case .unauthenticated:
            appState.currentUser = nil
        case .loading:
            // Set loading state
            break
        case .error:
            // Set error state
            break
        }
        
        return appState
    }
    
    static func previewLoading() -> AppState {
        let appState = AppState()
        // Set loading state
        return appState
    }
    
    static func previewError() -> AppState {
        let appState = AppState()
        // Set error state
        return appState
    }
}