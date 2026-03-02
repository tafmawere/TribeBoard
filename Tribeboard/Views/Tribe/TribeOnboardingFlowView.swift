import SwiftUI

struct TribeOnboardingFlowView: View {
    @StateObject private var store: TribeStore
    @State private var path: [Route] = []

    init(demoFlow: Bool = false) {
        _store = StateObject(wrappedValue: TribeStore(demoFlow: demoFlow))
    }

    var body: some View {
        NavigationStack(path: $path) {
            CreateTribeView(store: store) {
                path.append(.addMembers)
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .addMembers:
                    AddMembersView(store: store) {
                        path.append(.directory)
                    }
                case .directory:
                    TribeDirectoryView(store: store)
                }
            }
        }
    }
}

private enum Route: Hashable {
    case addMembers
    case directory
}

#Preview {
    TribeOnboardingFlowView()
}
