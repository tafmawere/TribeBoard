import SwiftUI

/// Primary notification center for run, driver, arrival, household, safety, and invitation updates.
///
/// Live path starts empty (no canned inbox). Push / activity feed wiring is a follow-up.
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
