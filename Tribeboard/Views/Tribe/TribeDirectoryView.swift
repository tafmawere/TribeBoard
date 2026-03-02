import SwiftUI
import UIKit

struct TribeDirectoryView: View {
    @ObservedObject var store: TribeStore

    @State private var searchText = ""
    @State private var isShowingEditor = false
    @State private var editorType: MemberType = .adult
    @State private var selectedMemberID: UUID?
    @State private var isShowingQuickActions = false
    @State private var isShowingAddChild = false
    @State private var isShowingAddVenue = false
    @State private var activeSharePayload: SharePayload?

    private var adults: [TribeMember] {
        store.adults(matching: searchText)
    }

    private var children: [TribeMember] {
        store.children(matching: searchText)
    }

    var body: some View {
        ZStack {
            TribeTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Mobility Command Center")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(TribeTheme.textPrimary)

                        TribeSearchBar(searchText: $searchText)

                        if let tribe = store.tribe {
                            tribeCommandCard(tribe: tribe)
                        }

                        TribeCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Operational Readiness")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(TribeTheme.textPrimary)
                                HStack(spacing: 8) {
                                    summaryPill(title: "Admins", value: adminCount)
                                    summaryPill(title: "Drivers", value: driverCount)
                                    summaryPill(title: "Children", value: childrenCount)
                                }
                                HStack(spacing: 8) {
                                    summaryPill(title: "Venues", value: totalVenuesCount)
                                    summaryPill(title: "Rules", value: totalRulesCount)
                                }
                            }
                        }

                        configurationHealthSection

                        if !adults.isEmpty {
                            MemberSectionHeader(title: "Adults", count: adults.count)
                            ForEach(adults) { member in
                                adultCommandRow(member: member)
                            }
                        }

                        if !children.isEmpty {
                            MemberSectionHeader(title: "Children", count: children.count)
                            ForEach(children) { member in
                                ChildCommandRow(
                                    member: member,
                                    configuration: store.childConfigurationSummary(for: member.id),
                                    nextRun: store.nextUpcomingRun(for: member.id),
                                    scheduleCount: store.ruleCount(for: member.id),
                                    onRowTap: { selectedMemberID = member.id },
                                    onAvatarTap: { selectedMemberID = member.id }
                                )
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Tribe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingQuickActions = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .confirmationDialog("Quick Actions", isPresented: $isShowingQuickActions, titleVisibility: .visible) {
            Button("Add Adult") {
                editorType = .adult
                isShowingEditor = true
            }
            Button("Add Child") {
                isShowingAddChild = true
            }
            Button("Add Venue") {
                isShowingAddVenue = true
            }
            if let tribeCode = store.tribe?.tribeCode, !tribeCode.isEmpty {
                Button("Share Tribe") {
                    activeSharePayload = SharePayload(items: [tribeCode])
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $isShowingEditor) {
            MemberEditorView(defaultType: editorType) { newMember in
                store.addMember(newMember)
            }
        }
        .sheet(isPresented: $isShowingAddChild) {
            NavigationStack {
                ChildSetupFlowView(store: store)
            }
        }
        .sheet(isPresented: $isShowingAddVenue) {
            NavigationStack {
                LocationsManagementView(store: store)
            }
        }
        .sheet(item: $activeSharePayload) { payload in
            ShareSheet(activityItems: payload.items)
        }
        .sheet(item: selectedMemberBinding) { memberID in
            MemberProfileView(store: store, memberID: memberID.value)
        }
    }

    private var adminCount: Int {
        store.members.filter { $0.permissions.contains(.admin) || $0.roles.contains(.admin) }.count
    }

    private var driverCount: Int {
        store.members.filter { $0.permissions.contains(.driver) || $0.roles.contains(.driver) }.count
    }

    private var childrenCount: Int {
        store.members.filter { $0.memberType == .child }.count
    }

    private var hasHomeSet: Bool {
        if let homeLocationId = store.tribe?.homeLocationId {
            return store.locations.contains(where: { $0.id == homeLocationId })
        }
        return store.locations.contains(where: { $0.type == .home })
    }

    private var childrenMissingSchedulesCount: Int {
        store.members
            .filter { $0.memberType == .child }
            .filter { store.ruleCount(for: $0.id) == 0 }
            .count
    }

    private var configurationWarnings: [String] {
        var warnings: [String] = []
        if driverCount == 0 {
            warnings.append("No driver configured")
        }
        if childrenMissingSchedulesCount > 0 {
            warnings.append("\(childrenMissingSchedulesCount) child without schedules")
        }
        if !hasHomeSet {
            warnings.append("Home location not set")
        }
        return warnings
    }

    private var roleSummaryText: String {
        "\(store.members.count) Members • \(driverCount) Driver\(driverCount == 1 ? "" : "s") • \(childrenCount) Child\(childrenCount == 1 ? "" : "ren")"
    }

    private var totalVenuesCount: Int {
        let linked = store.locations.filter {
            $0.type != .home && ($0.childId != nil || !$0.linkedChildIds.isEmpty)
        }
        let linkedIDs = Set(linked.map(\.id))
        if !linkedIDs.isEmpty {
            return linkedIDs.count
        }

        let inferred = Set(store.scheduleTemplates.compactMap { template in
            if let venue = template.venueId { return venue }
            return template.type == .dropoff ? template.destinationLocationId : template.originLocationId
        })
        return inferred.count
    }

    private var totalRulesCount: Int {
        let ruleIDs = Set(store.scheduleTemplates.compactMap(\.venueRuleId))
        if !ruleIDs.isEmpty {
            return ruleIDs.count
        }
        let childIDs = store.members.filter { $0.memberType == .child }.map(\.id)
        return childIDs.reduce(0) { $0 + store.ruleCount(for: $1) }
    }

    private func summaryPill(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(TribeTheme.textPrimary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TribeTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(TribeTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tribeCommandCard(tribe: Tribe) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [TribeTheme.primary.opacity(0.14), Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                Text(tribe.name)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(TribeTheme.textPrimary)

                Text(roleSummaryText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TribeTheme.textSecondary)

                Text(tribe.tribeCode)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(TribeTheme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(TribeTheme.primary.opacity(0.12))
                    .clipShape(Capsule())

                HStack(spacing: 10) {
                    Button {
                        activeSharePayload = SharePayload(items: [tribe.tribeCode])
                    } label: {
                        Label("Share Tribe", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(TribeTheme.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIPasteboard.general.string = tribe.tribeCode
                    } label: {
                        Text("Copy Code")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TribeTheme.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(TribeTheme.primary.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
            }
            .padding(16)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(TribeTheme.primary.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }

    private var configurationHealthSection: some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Configuration Health")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TribeTheme.textPrimary)

                if configurationWarnings.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.green.opacity(0.88))
                        Text("Tribe fully configured")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.green.opacity(0.88))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.10))
                    .clipShape(Capsule())
                } else {
                    ForEach(configurationWarnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.orange.opacity(0.9))
                                .padding(.top, 2)
                            Text(warning)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(TribeTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func adultCommandRow(member: TribeMember) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MemberAvatarView(member: member, size: 46, showsStatus: true)
                .padding(.top, 1)
                .onTapGesture {
                    selectedMemberID = member.id
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(member.fullName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TribeTheme.textPrimary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(member.isDriver ? TribeTheme.primary : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text(member.isDriver ? "Driver enabled" : "No driver role")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TribeTheme.textSecondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(member.roles.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { role in
                            roleChip(title: role.rawValue.uppercased(), role: role)
                        }
                    }
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            selectedMemberID = member.id
        }
    }

    private func roleChip(title: String, role: Role) -> some View {
        let isSoftRole = (role == .passenger || role == .child)
        return Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(TribeTheme.primary.opacity(isSoftRole ? 0.72 : 1))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TribeTheme.primary.opacity(isSoftRole ? 0.06 : 0.12))
            .clipShape(Capsule())
    }

    private var selectedMemberBinding: Binding<SelectedMember?> {
        Binding<SelectedMember?>(
            get: {
                guard let selectedMemberID else { return nil }
                return SelectedMember(value: selectedMemberID)
            },
            set: { value in
                selectedMemberID = value?.value
            }
        )
    }
}

private struct SelectedMember: Identifiable {
    let value: UUID
    var id: UUID { value }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ChildCommandRow: View {
    let member: TribeMember
    let configuration: ChildConfigurationSummary
    let nextRun: RunSuggestion?
    let scheduleCount: Int
    var onRowTap: (() -> Void)? = nil
    var onAvatarTap: (() -> Void)? = nil

    private var statusColor: Color {
        switch configuration.level {
        case .configured: return Color.green.opacity(0.9)
        case .partial: return Color.orange.opacity(0.95)
        case .notConfigured: return Color.red.opacity(0.9)
        }
    }

    private var nextRunText: String {
        guard let nextRun else { return "Next: Not scheduled" }
        return "Next: \(nextRunDateText(nextRun.proposedStart)) \(nextRun.destinationName)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MemberAvatarView(member: member, size: 46, showsStatus: true)
                .padding(.top, 1)
                .onTapGesture {
                    onAvatarTap?()
                }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(member.fullName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TribeTheme.textPrimary)
                }

                Text(configuration.statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TribeTheme.textSecondary)

                Text(scheduleCount > 0 ? "\(scheduleCount) schedule rule\(scheduleCount == 1 ? "" : "s")" : "Setup incomplete")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(scheduleCount > 0 ? TribeTheme.primary : Color.orange.opacity(0.92))

                Text(nextRunText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TribeTheme.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(member.roles.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { role in
                            let isSoftRole = (role == .passenger || role == .child)
                            Text(role.rawValue.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(TribeTheme.primary.opacity(isSoftRole ? 0.72 : 1))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(TribeTheme.primary.opacity(isSoftRole ? 0.06 : 0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            onRowTap?()
        }
    }

    private func nextRunDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        TribeDirectoryView(store: TribeStore(demoFlow: true))
    }
}
