import SwiftUI
import Combine

/// Enhanced navigation system with better state management and accessibility
@MainActor
class EnhancedNavigationManager: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var currentTab: NavigationTab = .dashboard
    @Published var isNavigating = false
    
    private var navigationHistory: [NavigationDestination] = []
    private let maxHistorySize = 20
    
    /// Navigate to a specific destination with animation and accessibility support
    func navigate(to destination: NavigationDestination, animated: Bool = true) {
        guard !isNavigating else { return }
        
        isNavigating = true
        
        // Add to history
        addToHistory(destination)
        
        // Perform navigation
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                navigationPath.append(destination)
            }
        } else {
            navigationPath.append(destination)
        }
        
        // Announce navigation to accessibility
        EnhancedAccessibility.announceScreenChange()
        
        // Provide haptic feedback
        HapticManager.shared.lightImpact()
        
        // Reset navigation flag after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isNavigating = false
        }
    }
    
    /// Pop the current view with animation and accessibility support
    func pop(animated: Bool = true) {
        guard !navigationPath.isEmpty, !isNavigating else { return }
        
        isNavigating = true
        
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                navigationPath.removeLast()
            }
        } else {
            navigationPath.removeLast()
        }
        
        // Remove from history
        if !navigationHistory.isEmpty {
            navigationHistory.removeLast()
        }
        
        // Announce navigation to accessibility
        EnhancedAccessibility.announceScreenChange()
        
        // Provide haptic feedback
        HapticManager.shared.lightImpact()
        
        // Reset navigation flag after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isNavigating = false
        }
    }
    
    /// Pop to root with animation and accessibility support
    func popToRoot(animated: Bool = true) {
        guard !navigationPath.isEmpty, !isNavigating else { return }
        
        isNavigating = true
        
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                navigationPath = NavigationPath()
            }
        } else {
            navigationPath = NavigationPath()
        }
        
        // Clear history
        navigationHistory.removeAll()
        
        // Announce navigation to accessibility
        EnhancedAccessibility.announceScreenChange()
        
        // Provide haptic feedback
        HapticManager.shared.lightImpact()
        
        // Reset navigation flag after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isNavigating = false
        }
    }
    
    /// Switch tabs with proper state management
    func switchTab(to tab: NavigationTab, animated: Bool = true) {
        guard currentTab != tab, !isNavigating else { return }
        
        isNavigating = true
        
        // Clear navigation path when switching tabs
        navigationPath = NavigationPath()
        navigationHistory.removeAll()
        
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentTab = tab
            }
        } else {
            currentTab = tab
        }
        
        // Announce tab change to accessibility
        EnhancedAccessibility.announce("Switched to \(tab.displayName)")
        
        // Provide haptic feedback
        HapticManager.shared.lightImpact()
        
        // Reset navigation flag after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isNavigating = false
        }
    }
    
    /// Check if we can navigate back
    var canGoBack: Bool {
        !navigationPath.isEmpty
    }
    
    /// Get current navigation depth
    var navigationDepth: Int {
        navigationHistory.count
    }
    
    /// Get navigation history for debugging
    var historyDescription: String {
        navigationHistory.map { $0.description }.joined(separator: " → ")
    }
    
    private func addToHistory(_ destination: NavigationDestination) {
        navigationHistory.append(destination)
        
        // Limit history size
        if navigationHistory.count > maxHistorySize {
            navigationHistory.removeFirst()
        }
    }
}

/// Navigation destinations for type-safe navigation
enum NavigationDestination: Hashable, CustomStringConvertible {
    case familySelection
    case createFamily
    case joinFamily
    case roleSelection
    case familyDashboard
    case memberDetail(UUID)
    case settings
    case profile
    
    var description: String {
        switch self {
        case .familySelection: return "Family Selection"
        case .createFamily: return "Create Family"
        case .joinFamily: return "Join Family"
        case .roleSelection: return "Role Selection"
        case .familyDashboard: return "Family Dashboard"
        case .memberDetail: return "Member Detail"
        case .settings: return "Settings"
        case .profile: return "Profile"
        }
    }
}

/// Enhanced navigation view modifier
struct EnhancedNavigationView: ViewModifier {
    @StateObject private var navigationManager = EnhancedNavigationManager()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        NavigationStack(path: $navigationManager.navigationPath) {
            content
                .navigationDestination(for: NavigationDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .environmentObject(navigationManager)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: navigationManager.currentTab)
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .familySelection:
            FamilySelectionView()
        case .createFamily:
            CreateFamilyView()
        case .joinFamily:
            JoinFamilyView()
        case .roleSelection:
            RoleSelectionView()
        case .familyDashboard:
            FamilyDashboardView()
        case .memberDetail(let memberId):
            // MemberDetailView(memberId: memberId)
            Text("Member Detail: \(memberId)")
        case .settings:
            SettingsView(currentUserId: UUID(), currentUserRole: .adult)
        case .profile:
            // ProfileView()
            Text("Profile View")
        }
    }
}

extension View {
    /// Apply enhanced navigation to any view
    func enhancedNavigation() -> some View {
        modifier(EnhancedNavigationView())
    }
}

/// Navigation bar utilities
struct NavigationBarUtilities {
    
    /// Create a back button with accessibility support
    static func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                Text("Back")
                    .font(.body)
            }
            .foregroundColor(.brandPrimary)
        }
        .accessibilityLabel("Go back")
        .accessibilityHint("Returns to the previous screen")
        .accessibilityAddTraits([.isButton])
    }
    
    /// Create a close button with accessibility support
    static func closeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("Close")
        .accessibilityHint("Closes the current screen")
        .accessibilityAddTraits([.isButton])
    }
    
    /// Create a menu button with accessibility support
    static func menuButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.brandPrimary)
        }
        .accessibilityLabel("Menu")
        .accessibilityHint("Opens the menu with additional options")
        .accessibilityAddTraits([.isButton])
    }
}

/// Deep linking support
struct DeepLinkHandler {
    
    /// Handle deep link URLs
    @MainActor
    static func handle(_ url: URL, navigationManager: EnhancedNavigationManager) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else { return }
        
        switch host {
        case "family":
            if let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                // Navigate to join family with pre-filled code
                navigationManager.navigate(to: .joinFamily)
                // TODO: Pre-fill family code
            }
        case "dashboard":
            navigationManager.switchTab(to: .dashboard)
        case "settings":
            navigationManager.navigate(to: .settings)
        default:
            break
        }
    }
    
    /// Generate deep link URL
    static func generateURL(for destination: NavigationDestination) -> URL? {
        switch destination {
        case .familySelection:
            return URL(string: "tribeboard://family")
        case .createFamily:
            return URL(string: "tribeboard://family/create")
        case .joinFamily:
            return URL(string: "tribeboard://family/join")
        case .familyDashboard:
            return URL(string: "tribeboard://dashboard")
        case .settings:
            return URL(string: "tribeboard://settings")
        default:
            return nil
        }
    }
}

/// Navigation state persistence
struct NavigationStatePersistence {
    private static let navigationStateKey = "NavigationState"
    
    /// Save navigation state
    static func save(_ state: NavigationState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: navigationStateKey)
        }
    }
    
    /// Load navigation state
    static func load() -> NavigationState? {
        guard let data = UserDefaults.standard.data(forKey: navigationStateKey),
              let state = try? JSONDecoder().decode(NavigationState.self, from: data) else {
            return nil
        }
        return state
    }
    
    /// Clear saved navigation state
    static func clear() {
        UserDefaults.standard.removeObject(forKey: navigationStateKey)
    }
}

/// Navigation state for persistence
struct NavigationState: Codable {
    let currentTab: String
    let navigationDepth: Int
    let timestamp: Date
    
    init(tab: NavigationTab, depth: Int) {
        self.currentTab = tab.rawValue
        self.navigationDepth = depth
        self.timestamp = Date()
    }
}