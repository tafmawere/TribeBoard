import SwiftUI

struct LocationSharingSettingsView: View {
    @State private var shareDuringActiveRunsOnly = true
    @State private var shareAlways = false
    @State private var visibleRoles: Set<ViewerRole> = [.parents, .driver]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                sharingModesCard
                viewersCard
                privacyInfoCard
            }
            .padding(16)
        }
        .background(SafetyTheme.background.ignoresSafeArea())
        .navigationTitle("Location Sharing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sharingModesCard: some View {
        SafetyCard {
            VStack(alignment: .leading, spacing: 14) {
                SafetySectionTitle(title: "When to Share")

                Toggle(isOn: $shareDuringActiveRunsOnly) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share during active runs only")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SafetyTheme.textPrimary)
                        Text("Visible while a run is in progress.")
                            .font(.system(size: 13))
                            .foregroundStyle(SafetyTheme.textSecondary)
                    }
                }
                .tint(SafetyTheme.tint)
                .onChange(of: shareDuringActiveRunsOnly) { _, newValue in
                    if newValue {
                        shareAlways = false
                    }
                }

                Divider()

                Toggle(isOn: $shareAlways) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share always")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SafetyTheme.textPrimary)
                        Text("Visible even outside scheduled runs.")
                            .font(.system(size: 13))
                            .foregroundStyle(SafetyTheme.textSecondary)
                    }
                }
                .tint(SafetyTheme.tint)
                .onChange(of: shareAlways) { _, newValue in
                    if newValue {
                        shareDuringActiveRunsOnly = false
                    }
                }
            }
        }
    }

    private var viewersCard: some View {
        SafetyCard {
            VStack(alignment: .leading, spacing: 14) {
                SafetySectionTitle(title: "Who Can See Me")
                Text("Choose who can view your live location. You can select more than one group.")
                    .font(.system(size: 13))
                    .foregroundStyle(SafetyTheme.textSecondary)

                HStack(spacing: 8) {
                    ForEach(ViewerRole.allCases, id: \.self) { role in
                        SafetyChip(text: role.label, isSelected: visibleRoles.contains(role)) {
                            toggleRole(role)
                        }
                    }
                }
            }
        }
    }

    private var privacyInfoCard: some View {
        SafetyCard {
            VStack(alignment: .leading, spacing: 12) {
                SafetySectionTitle(title: "Privacy Notes")
                SafetyInfoCard(
                    iconName: "lock.shield",
                    title: "Your controls stay in your hands",
                    detail: "These are demo settings for UI flow only and can be adjusted anytime.",
                    accent: SafetyTheme.tint
                )
                SafetyInfoCard(
                    iconName: "timer",
                    title: "Time-aware sharing",
                    detail: "Active-run mode helps minimize visibility outside pickups and drop-offs.",
                    accent: SafetyTheme.success
                )
            }
        }
    }

    private func toggleRole(_ role: ViewerRole) {
        if visibleRoles.contains(role) {
            visibleRoles.remove(role)
        } else {
            visibleRoles.insert(role)
        }
    }
}

private enum ViewerRole: CaseIterable {
    case parents
    case driver
    case observers

    var label: String {
        switch self {
        case .parents:
            return "Parents"
        case .driver:
            return "Driver"
        case .observers:
            return "Observers"
        }
    }
}

#Preview {
    NavigationStack {
        LocationSharingSettingsView()
    }
}
