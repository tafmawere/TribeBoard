import SwiftUI

struct CalendarHubView: View {
    var body: some View {
        Text("Calendar Hub (TODO)")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CalendarHubView()
    }
}
