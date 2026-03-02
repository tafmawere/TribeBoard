import SwiftUI
import Combine

@MainActor
final class NavigationRouter: ObservableObject {
    @Published var homePath = NavigationPath()
    @Published var runsPath = NavigationPath()
    @Published var calendarPath = NavigationPath()
    @Published var familyPath = NavigationPath()
    @Published var morePath = NavigationPath()

    func pathBinding(for tab: AppTab) -> Binding<NavigationPath> {
        Binding(
            get: { self.path(for: tab) },
            set: { self.setPath($0, for: tab) }
        )
    }

    func push(_ destination: Destination, on tab: AppTab) {
        switch tab {
        case .home:
            homePath.append(destination)
        case .runs:
            runsPath.append(destination)
        case .calendar:
            calendarPath.append(destination)
        case .family:
            familyPath.append(destination)
        case .more:
            morePath.append(destination)
        }
    }

    func popToRoot(on tab: AppTab) {
        switch tab {
        case .home:
            homePath = NavigationPath()
        case .runs:
            runsPath = NavigationPath()
        case .calendar:
            calendarPath = NavigationPath()
        case .family:
            familyPath = NavigationPath()
        case .more:
            morePath = NavigationPath()
        }
    }

    private func path(for tab: AppTab) -> NavigationPath {
        switch tab {
        case .home:
            return homePath
        case .runs:
            return runsPath
        case .calendar:
            return calendarPath
        case .family:
            return familyPath
        case .more:
            return morePath
        }
    }

    private func setPath(_ newPath: NavigationPath, for tab: AppTab) {
        switch tab {
        case .home:
            homePath = newPath
        case .runs:
            runsPath = newPath
        case .calendar:
            calendarPath = newPath
        case .family:
            familyPath = newPath
        case .more:
            morePath = newPath
        }
    }
}
