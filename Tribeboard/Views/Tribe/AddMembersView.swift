import SwiftUI

struct AddMembersView: View {
    @ObservedObject var store: TribeStore
    let onContinue: () -> Void

    @State private var editorType: MemberType = .adult
    @State private var editingMember: TribeMember?
    @State private var isShowingAddPerson = false
    @State private var isShowingJoinFamily = false

    var body: some View {
        ZStack {
            TribeTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    TribeCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                openAddPerson(type: .adult)
                            } label: {
                                Text("Add person")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(TribeTheme.primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                isShowingJoinFamily = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 14, weight: .semibold))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Invite with a code")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Join an existing family using an invite code.")
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(TribeTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 11)
                                .background(TribeTheme.primary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Text("Adults can manage or drive Runs. Kids are passengers.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }

                    sectionHeader(title: "Adults", count: store.adults().count)
                    if store.adults().isEmpty {
                        emptyStateCard(
                            icon: "person.2.fill",
                            text: "No adults yet. Add a parent, guardian, or helper."
                        )
                    } else {
                        ForEach(store.adults()) { member in
                            onboardingMemberRow(member: member)
                        }
                    }

                    sectionHeader(title: "Kids", count: store.children().count)
                    if store.children().isEmpty {
                        emptyStateCard(
                            icon: "figure.2.and.child.holdinghands",
                            text: "No kids yet. Add your children so they can be assigned to Runs."
                        )
                    } else {
                        ForEach(store.children()) { member in
                            onboardingMemberRow(member: member)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 74)
            }
        }
        .navigationTitle("Add members")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingJoinFamily) {
            JoinFamilyView(store: store)
        }
        .fullScreenCover(isPresented: $isShowingAddPerson) {
            AddPersonView(existingMember: editingMember, defaultType: editorType) { member in
                if editingMember == nil {
                    store.addMember(member)
                } else {
                    store.updateMember(member)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomContinueBar
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Step 3 of 6")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Add your family")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(TribeTheme.textPrimary)

            Text("Add the people who help with Runs and schedules.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding(.top, -2)
    }

    private var canContinue: Bool {
        !store.adults().isEmpty
    }

    private var bottomContinueBar: some View {
        VStack(spacing: 4) {
            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(TribeTheme.primary)
                    .clipShape(Capsule())
            }
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.6)

            Text(continueHint)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(
            Color(red: 0.976, green: 0.980, blue: 0.984)
                .ignoresSafeArea()
        )
    }

    private var continueHint: String {
        "Add at least one adult to continue."
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(TribeTheme.textPrimary)

            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TribeTheme.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(TribeTheme.primary.opacity(0.12))
                .clipShape(Capsule())

            Spacer()
        }
    }

    private func openAddPerson(type: MemberType) {
        editorType = type
        editingMember = nil
        isShowingAddPerson = true
    }

    private func onboardingMemberRow(member: TribeMember) -> some View {
        Button {
            editorType = member.memberType
            editingMember = member
            isShowingAddPerson = true
        } label: {
            HStack(spacing: 12) {
                MemberAvatarView(member: member, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(member.fullName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TribeTheme.textPrimary)

                    Text(member.relationship?.isEmpty == false ? member.relationship! : (member.memberType == .adult ? "Adult" : "Child"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(displayBadges(for: member), id: \.self) { badge in
                            badgeView(title: badge)
                        }
                        let overflow = member.roleBadges.count - min(member.roleBadges.count, 2)
                        if overflow > 0 {
                            badgeView(title: "+\(overflow)")
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func emptyStateCard(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TribeTheme.primary)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 54)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.03), lineWidth: 0.5)
        }
    }

    private func displayBadges(for member: TribeMember) -> [String] {
        Array(member.roleBadges.prefix(2))
    }

    private func badgeView(title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(TribeTheme.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TribeTheme.primary.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct JoinFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TribeStore
    @State private var inviteCode = ""

    var body: some View {
        ZStack {
            TribeTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                TribeCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Join a family")
                            .font(.system(size: 30, weight: .bold))
                        Text("Enter the invite code shared with you.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)

                        TextField("Invite code", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                Button("Continue") {
                    let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let currentName = store.tribe?.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.createTribe(
                        name: (currentName?.isEmpty == false ? currentName! : "Joined Family"),
                        tribeCode: trimmed
                    )
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TribeTheme.primary)
                .clipShape(Capsule())
                .disabled(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .navigationTitle("Join Family")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AddMembersView(store: TribeStore(demoFlow: true)) { }
    }
}
