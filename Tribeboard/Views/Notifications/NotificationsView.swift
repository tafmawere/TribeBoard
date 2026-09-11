import SwiftUI

/// Primary notification center for run, driver, arrival, household, safety, and invitation updates.
///
/// TODO: Replace mock inbox data with a unified notification feed backed by push history,
/// in-app events, and household activity streams.
struct NotificationsView: View {
    var body: some View {
        NotificationsInboxView()
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
