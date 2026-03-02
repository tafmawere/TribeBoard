import SwiftUI

enum DriverModeUIState: Int, CaseIterable {
    case enRoute
    case pickupArrival
    case dropoffArrival
    case complete
}

struct DriverModeUIScreen: View {
    let run: UIRun
    let onCompleteRun: () -> Void

    @State private var state: DriverModeUIState = .enRoute
    @State private var pickupCheckedPassengerIDs: Set<UUID> = []
    @State private var dropoffCheckedPassengerIDs: Set<UUID> = []

    private var checklistPassengers: [UIPassenger] {
        switch state {
        case .pickupArrival:
            return UIRunMockData.passengerChecklistPickup
        case .dropoffArrival:
            return UIRunMockData.passengerChecklistDropoff
        default:
            return []
        }
    }

    var body: some View {
        ZStack {
            backgroundForState
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    stateContent
                }
                .padding(16)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle(state == .enRoute ? "En Route" : "Driver Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        UICard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Current Status")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                    Text(stateTitle)
                        .font(.system(size: 31, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                }
                Spacer()
                Text("Step \(state.rawValue + 1) of 4")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(UIRunDesignSystem.primary)
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch state {
        case .enRoute:
            enRouteView
        case .pickupArrival:
            pickupView
        case .dropoffArrival:
            dropoffView
        case .complete:
            completeView
        }
    }

    private var enRouteView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Arriving In")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)

            Text(run.etaText)
                .font(.system(size: 68, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)

            UIRunCard(run: run) {
                // UI-only
            }

            UIPrimaryButton(title: "Mark Arrived at Pickup", icon: "location.fill") {
                state = .pickupArrival
            }
        }
    }

    private var pickupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confirm passengers boarded")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)

            ForEach(checklistPassengers) { passenger in
                UIPassengerRow(
                    passenger: passenger,
                    isSelectable: true,
                    isSelected: pickupCheckedPassengerIDs.contains(passenger.id)
                ) {
                    togglePickup(passenger.id)
                }
            }

            UIPrimaryButton(title: "All Passengers Boarded") {
                state = .dropoffArrival
            }
            .opacity(pickupCheckedPassengerIDs.count >= 1 ? 1.0 : 0.55)
            .disabled(pickupCheckedPassengerIDs.isEmpty)

            HStack(spacing: 10) {
                UISecondaryButton(title: "Notify Family", icon: "message.fill") {}
                UISecondaryButton(title: "Wait 5m", icon: "timer") {}
            }
        }
    }

    private var dropoffView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Almost there, Maya is arriving")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.blue.opacity(0.15))
                .frame(height: 160)
                .overlay {
                    Image(systemName: "map")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.primary.opacity(0.70))
                }

            UICard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CURRENT PASSENGER")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(UIRunDesignSystem.primary)
                        Text("Maya's School")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)
                        Text("123 Education Lane")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    }
                    Spacer()
                }
            }

            UIPrimaryButton(title: "I've Arrived", icon: "mappin.and.ellipse") {
                state = .complete
            }

            UISecondaryButton(title: "Dropped Off Maya", icon: "figure.walk.arrival") {
                dropoffCheckedPassengerIDs.insert(checklistPassengers.first?.id ?? UUID())
                state = .complete
            }
        }
    }

    private var completeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            UICard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Run Wrap-up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                    Text("All passengers safely dropped off.")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                    Text("Review summary and finish this run.")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                }
            }

            UIPrimaryButton(title: "End Run", icon: "checkmark.circle.fill") {
                onCompleteRun()
            }
        }
    }

    private var stateTitle: String {
        switch state {
        case .enRoute: return "En Route"
        case .pickupArrival: return "Pickup Confirmation"
        case .dropoffArrival: return "Confirming Arrival"
        case .complete: return "Ready to Complete"
        }
    }

    private var backgroundForState: some View {
        Group {
            if state == .enRoute {
                Color(red: 0.035, green: 0.050, blue: 0.120)
            } else {
                UIRunDesignSystem.background
            }
        }
    }

    private func togglePickup(_ id: UUID) {
        if pickupCheckedPassengerIDs.contains(id) {
            pickupCheckedPassengerIDs.remove(id)
        } else {
            pickupCheckedPassengerIDs.insert(id)
        }
    }
}

#Preview {
    NavigationStack {
        DriverModeUIScreen(run: UIRunMockData.activeRun, onCompleteRun: {})
    }
}
