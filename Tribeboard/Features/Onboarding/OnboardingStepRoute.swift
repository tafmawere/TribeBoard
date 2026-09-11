import Foundation

enum OnboardingStepRoute: Hashable, Codable {
    case welcome
    case invitedAcceptance
    case joinCode
    case joinProfile
    case joinResult
    case setupProfile
    case setupTribe
    case setupHome
    case setupChildren
    case childSetupList
    case childSchool(childId: UUID)
    case childRoutine(childId: UUID)
    case childActivities(childId: UUID)
    case supportPeople
    case review
    case nextUp
    case finishing

    var title: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .invitedAcceptance:
            return "Invitation"
        case .joinCode:
            return "Join a Tribe"
        case .joinProfile:
            return "Your Profile"
        case .joinResult:
            return "Join Status"
        case .setupProfile:
            return "Your Profile"
        case .setupTribe:
            return "Create Your Family"
        case .setupHome:
            return "Home Location"
        case .setupChildren:
            return "Add Children"
        case .childSetupList:
            return "Child Setup"
        case .childSchool:
            return "School"
        case .childRoutine:
            return "Routine"
        case .childActivities:
            return "Activities"
        case .supportPeople:
            return "Support People"
        case .review:
            return "Review"
        case .nextUp:
            return "Next Up"
        case .finishing:
            return "Finishing Setup"
        }
    }

    var progressStepTitle: String? {
        switch self {
        case .setupProfile:
            return "Your Profile"
        case .setupTribe:
            return "Create Your Family"
        case .setupHome:
            return "Home Location"
        case .nextUp:
            return "Next Up"
        default:
            return nil
        }
    }
}
