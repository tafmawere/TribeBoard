import SwiftUI

struct LaunchRootView: View {
    var body: some View {
        Group {
            if AppConfig.isDemoFlowEnabled {
                DemoShellView()
            } else {
                HomeView()
            }
        }
    }
}

#Preview {
    LaunchRootView()
}
