import SwiftUI

struct RunFocusUIScreen: View {
    let run: UIRun
    let isDriver: Bool
    let onStartRun: () -> Void

    var body: some View {
        ZStack {
            UIRunDesignSystem.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    heroMap

                    UICard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                            Text("Ready to go")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                            Text("\(run.etaText) • \(run.distanceText)")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.secondary)
                        }
                    }

                    Text("Route Summary")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                        .padding(.top, 2)

                    UICard {
                        VStack(spacing: 8) {
                            ForEach(Array(run.stops.enumerated()), id: \.element.id) { index, stop in
                                UIStopRow(stop: stop, isCurrent: index == 0)
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        ForEach(run.passengers) { passenger in
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(UIRunDesignSystem.primary.opacity(0.14))
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        Text(initials(passenger.name))
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(UIRunDesignSystem.primary)
                                    }
                                Text(firstName(passenger.name))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 6)

                    if isDriver {
                        UIPrimaryButton(title: "Start Run", icon: "play.fill", action: onStartRun)
                    }

                    UISecondaryButton(title: "Open in Maps", icon: "map.fill") {
                        // UI-only button.
                    }
                }
                .padding(16)
                .padding(.bottom, 12)
            }
        }
        .navigationTitle("Run Focus")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroMap: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.green.opacity(0.25), Color.blue.opacity(0.22)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 200)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                    Text(run.status == .active ? "Active Run" : "Not Started")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.primary)
                }
                .padding(14)
            }
            .overlay {
                Image(systemName: "map.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
    }

    private func initials(_ fullName: String) -> String {
        fullName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private func firstName(_ fullName: String) -> String {
        fullName.split(separator: " ").first.map(String.init) ?? fullName
    }
}

#Preview {
    NavigationStack {
        RunFocusUIScreen(
            run: UIRunMockData.scheduledRun,
            isDriver: true,
            onStartRun: {}
        )
    }
}
