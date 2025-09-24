import Foundation

/// Represents a child profile with basic information for school run assignments
struct ChildProfile: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var avatar: String
    var age: Int
    
    /// Computed property that returns display text with name and age
    var displayName: String {
        return "\(name) (\(age))"
    }
    
    /// Computed property that returns age group description
    var ageGroup: String {
        switch age {
        case 0...5:
            return "Preschool"
        case 6...10:
            return "Elementary"
        case 11...13:
            return "Middle School"
        case 14...18:
            return "High School"
        default:
            return "Adult"
        }
    }
    
    /// Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Equatable conformance
    static func == (lhs: ChildProfile, rhs: ChildProfile) -> Bool {
        return lhs.id == rhs.id
    }
}