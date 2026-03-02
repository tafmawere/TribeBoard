import SwiftUI

struct PermissionsConsentView: View {
    @State private var children: [ConsentChild] = [
        ConsentChild(name: "TJ", role: "Passenger", status: .accepted),
        ConsentChild(name: "Tawana", role: "Passenger", status: .pending),
        ConsentChild(name: "Maya", role: "Observer", status: .pending)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard

                ForEach(children.indices, id: \.self) { index in
                    childConsentCard(for: index)
                }
            }
            .padding(16)
        }
        .background(SafetyTheme.background.ignoresSafeArea())
        .navigationTitle("Consent")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        SafetyCard {
            VStack(alignment: .leading, spacing: 10) {
                SafetySectionTitle(title: "Kids Tracking Consent")
                Text("Consent is required before enabling youth location visibility in family runs.")
                    .font(.system(size: 13))
                    .foregroundStyle(SafetyTheme.textSecondary)
                SafetyInfoCard(
                    iconName: "hand.raised.fill",
                    title: "Parent-led controls",
                    detail: "This is a UI preview. No real consent request is sent.",
                    accent: SafetyTheme.warning
                )
            }
        }
    }

    private func childConsentCard(for index: Int) -> some View {
        let child = children[index]
        return SafetyCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(SafetyTheme.tint.opacity(0.14))
                        .frame(width: 42, height: 42)
                        .overlay {
                            Text(child.initials)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(SafetyTheme.tint)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(child.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(SafetyTheme.textPrimary)
                        Text(child.role)
                            .font(.system(size: 13))
                            .foregroundStyle(SafetyTheme.textSecondary)
                    }
                    Spacer()
                    SafetyBadge(text: child.status.badgeText, color: child.status.color)
                }

                if child.status == .pending {
                    SafetyPrimaryButton(title: "Request consent") {
                        print("Request consent tapped for \(child.name)")
                    }
                } else {
                    SafetySecondaryButton(title: "Request consent") {
                        print("Request consent tapped for \(child.name)")
                    }
                }
            }
        }
    }
}

private struct ConsentChild {
    let name: String
    let role: String
    let status: ConsentStatus

    var initials: String {
        let parts = name.split(separator: " ")
        if let first = parts.first?.first {
            return String(first).uppercased()
        }
        return "?"
    }
}

private enum ConsentStatus {
    case accepted
    case pending

    var badgeText: String {
        switch self {
        case .accepted:
            return "Accepted"
        case .pending:
            return "Pending"
        }
    }

    var color: Color {
        switch self {
        case .accepted:
            return SafetyTheme.success
        case .pending:
            return SafetyTheme.warning
        }
    }
}

#Preview {
    NavigationStack {
        PermissionsConsentView()
    }
}
