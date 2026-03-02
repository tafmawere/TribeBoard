import SwiftUI

struct FamilyHubView: View {
    var body: some View {
        Text("Family Hub (TODO)")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Family")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FamilyHubView()
    }
}
