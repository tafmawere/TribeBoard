import Foundation

/// Represents a single stop in a school run with location, assignment, and task information
struct RunStop: Identifiable, Codable {
    let id = UUID()
    var name: String
    var type: StopType
    var assignedChild: ChildProfile?
    var task: String
    var estimatedMinutes: Int
    var isCompleted: Bool = false
    
    /// Enum defining different types of stops with associated icons
    enum StopType: String, CaseIterable, Codable {
        case home = "Home"
        case school = "School"
        case ot = "OT"
        case music = "Music"
        case custom = "Custom"
        
        /// Icon representation for each stop type
        var icon: String {
            switch self {
            case .home: return "🏠"
            case .school: return "🏫"
            case .ot: return "🏥"
            case .music: return "🎵"
            case .custom: return "📍"
            }
        }
        
        /// SF Symbol representation for each stop type
        var sfSymbol: String {
            switch self {
            case .home: return "house.fill"
            case .school: return "building.2.fill"
            case .ot: return "cross.case.fill"
            case .music: return "music.note"
            case .custom: return "mappin.circle.fill"
            }
        }
    }
    
    /// Computed property that returns display text for the stop
    var displayName: String {
        return "\(type.icon) \(name)"
    }
    
    /// Computed property that formats estimated time for display
    var formattedDuration: String {
        if estimatedMinutes == 1 {
            return "1 minute"
        } else {
            return "\(estimatedMinutes) minutes"
        }
    }
}