import SwiftUI

struct TribeDirectoryView: View {
    @ObservedObject var store: TribeStore

    @State private var searchText = ""
    @State private var isShowingEditor = false
    @State private var editorType: MemberType = .adult
    @State private var selectedMemberID: UUID?

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
                        Text("Tribe Directory")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(TribeTheme.textPrimary)

                        TribeSearchBar(searchText: $searchText)

                        if let tribe = store.tribe {
                            Text("\(tribe.name) · \(tribe.tribeCode)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(TribeTheme.textSecondary)
                                .padding(.bottom, 2)
                        }

                        MemberSectionHeader(title: "Adults", count: adults.count)
                        ForEach(adults) { member in
                            MemberRow(
                                member: member,
                                onRowTap: { selectedMemberID = member.id },
                                onAvatarTap: { selectedMemberID = member.id }
                            )
                        }

                        MemberSectionHeader(title: "Children", count: children.count)
                        ForEach(children) { member in
                            MemberRow(
                                member: member,
                                onRowTap: { selectedMemberID = member.id },
                                onAvatarTap: { selectedMemberID = member.id }
                            )
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 84)
                }

                Button {
                    editorType = .adult
                    isShowingEditor = true
                } label: {
                    Text("Add Tribe Member")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TribeTheme.primary)
                        .clipShape(Capsule())
                        .shadow(color: TribeTheme.primary.opacity(0.2), radius: 12, x: 0, y: 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Directory")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingEditor) {
            MemberEditorView(defaultType: editorType) { newMember in
                store.addMember(newMember)
            }
        }
        .sheet(item: selectedMemberBinding) { memberID in
            MemberProfileView(store: store, memberID: memberID.value)
        }
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

#Preview {
    NavigationStack {
        TribeDirectoryView(store: TribeStore(demoFlow: true))
    }
}
