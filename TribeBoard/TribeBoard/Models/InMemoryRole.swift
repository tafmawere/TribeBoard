import Foundation

/// Simplified role enum for in-memory family management with SwiftUI picker compatibility
enum InMemoryRole: String, CaseIterable, Codable {
    case parent = "Parent"
    case child = "Child"
    case guardian = "Guardian"
    case helper = "Helper"
    
    /// Human-readable display name for SwiftUI picker
    var displayName: String {
        return rawValue
    }
    
    /// Description of the role's responsibilities
    var description: String {
        switch self {
        case .parent:
            return "Primary caregiver with full family management access"
        case .child:
            return "Family member with age-appropriate access and features"
        case .guardian:
            return "Trusted adult with supervisory responsibilities"
        case .helper:
            return "Support person who assists with family activities"
        }
    }
    
    /// Icon name for UI display (using SF Symbols)
    var iconName: String {
        switch self {
        case .parent:
            return "person.fill"
        case .child:
            return "person.crop.circle"
        case .guardian:
            return "shield.fill"
        case .helper:
            return "hand.raised.fill"
        }
    }
}

// MARK: - Identifiable Support for SwiftUI
extension InMemoryRole: Identifiable {
    var id: String { rawValue }
}