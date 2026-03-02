import SwiftUI

@main
struct TribeboardApp: App {
    @StateObject private var flow = AppFlowState()

    var body: some Scene {
        WindowGroup {
            RootFlowView()
                .environmentObject(flow)
        }
    }
}
