import SwiftUI

struct TribeDemoEntryView: View {
    @State private var isShowingTribeFlow = false

    var body: some View {
        ZStack {
            TribeTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Tribe Management")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(TribeTheme.textPrimary)

                Text("Open the demo flow to create your tribe and manage members.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(TribeTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    isShowingTribeFlow = true
                } label: {
                    Text("Open Tribe Management")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TribeTheme.primary)
                        .clipShape(Capsule())
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $isShowingTribeFlow) {
            TribeOnboardingFlowView()
        }
    }
}

#Preview {
    TribeDemoEntryView()
}
