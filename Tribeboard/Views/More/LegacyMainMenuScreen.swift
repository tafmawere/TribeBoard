import SwiftUI

struct LegacyMainMenuView: View {
    private let primaryRows: [LegacyMainMenuRowItem] = [
        .init(title: "Runs", icon: "car.fill"),
        .init(title: "Calendar", icon: "calendar"),
        .init(title: "Family", icon: "person.3.fill"),
        .init(title: "Notifications", icon: "bell.fill")
    ]

    private let secondaryRows: [LegacyMainMenuRowItem] = [
        .init(title: "Safety & Privacy", icon: "lock.shield.fill"),
        .init(title: "Settings", icon: "gearshape.fill"),
        .init(title: "Help", icon: "questionmark.circle.fill")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                legacyProfileHeader
                legacyMenuSection(title: "Quick Access", rows: primaryRows)
                legacyMenuSection(title: "Account & Support", rows: secondaryRows)
            }
            .padding(16)
        }
        .background(GeneralUXTheme.background.ignoresSafeArea())
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var legacyProfileHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(GeneralUXTheme.primary.opacity(0.14))
                .frame(width: 56, height: 56)
                .overlay {
                    Text("RM")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(GeneralUXTheme.primary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("Rue Mawere")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GeneralUXTheme.textPrimary)
                Text("Family organizer")
                    .font(.system(size: 13))
                    .foregroundStyle(GeneralUXTheme.textSecondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GeneralUXTheme.textSecondary)
        }
        .padding(18)
        .background(GeneralUXTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(GeneralUXTheme.border)
        )
    }

    private func legacyMenuSection(title: String, rows: [LegacyMainMenuRowItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(GeneralUXTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        Image(systemName: row.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(GeneralUXTheme.primary)
                            .frame(width: 30, height: 30)
                            .background(GeneralUXTheme.primary.opacity(0.12))
                            .clipShape(Circle())
                        Text(row.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(GeneralUXTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(GeneralUXTheme.textSecondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(14)
            .background(GeneralUXTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(GeneralUXTheme.border)
            )
        }
    }
}

private struct LegacyMainMenuRowItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
}

#Preview {
    NavigationStack {
        LegacyMainMenuView()
    }
}
