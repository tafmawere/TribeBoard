import SwiftUI

struct ObserverTrackingUIScreen: View {
    let run: UIRun
    let timeline: [UITimelineItem]

    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        ZStack {
            UIRunDesignSystem.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    topHero

                    etaCard

                    Text("Timeline")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                    UICard {
                        VStack(spacing: 4) {
                            ForEach(Array(timeline.enumerated()), id: \.element.id) { index, item in
                                UITimelineRow(item: item, isCurrent: index == 1)
                            }
                        }
                    }

                    Text("Passenger Status")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                    VStack(spacing: 10) {
                        ForEach(run.passengers) { passenger in
                            UIPassengerRow(passenger: passenger)
                        }
                    }

                    HStack(spacing: 10) {
                        UIPrimaryButton(title: "Call Driver", icon: "phone.fill") {
                            alertMessage = "Call Driver tapped."
                            showingAlert = true
                        }

                        UISecondaryButton(title: "Share Status", icon: "square.and.arrow.up") {
                            alertMessage = "Share Status tapped."
                            showingAlert = true
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Tracking Sarah's Run")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Observer Action", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var topHero: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.35), Color.teal.opacity(0.28)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 240)
            .overlay(alignment: .bottom) {
                HStack(spacing: 10) {
                    Image(systemName: "speedometer")
                        .foregroundStyle(UIRunDesignSystem.primary)
                    Text("24 mph")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.9))
                .clipShape(Capsule())
                .padding(.bottom, 14)
            }
    }

    private var etaCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Estimated Arrival")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)

                HStack(alignment: .lastTextBaseline) {
                    Text("3:45 PM")
                        .font(.system(size: 45, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                    Text("(12 min)")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.primary)
                    Spacer()
                    Text("On Schedule")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.primary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ObserverTrackingUIScreen(run: UIRunMockData.activeRun, timeline: UIRunMockData.timeline)
    }
}
