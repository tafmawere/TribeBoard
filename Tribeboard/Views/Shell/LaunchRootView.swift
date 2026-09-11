import SwiftUI

struct LaunchRootView: View {
    var body: some View {
        Group {
#if DEBUG
            if AppConfig.isDemoFlowEnabled {
                DemoShellView()
            } else {
                HomeView()
                    .environmentObject(RunDataSource())
            }
#else
            HomeView()
                .environmentObject(RunDataSource())
#endif
        }
    }
}

#Preview {
    LaunchRootView()
}
