import SwiftUI
import PhotosUI
import UIKit

struct MemberProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TribeStore
    let memberID: UUID

    @State private var isShowingEditor = false
    @State private var showingAvatarPickerSheet = false
    @State private var showingPhotoLibrary = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    private var member: TribeMember? {
        store.members.first(where: { $0.id == memberID })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TribeTheme.background.ignoresSafeArea()

                if let member {
                    ScrollView {
                        VStack(spacing: 14) {
                            headerCard(member)
                            rolesCard(member)
                            permissionsCard(member)
                            locationCard(member)
                            contactCard(member)
                            activityCard
                        }
                        .padding(20)
                    }
                } else {
                    ContentUnavailableView("Member unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
                }
            }
            .navigationTitle("Member Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                if member != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            isShowingEditor = true
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingEditor) {
                if let member {
                    MemberEditorView(existingMember: member, defaultType: member.memberType) { edited in
                        store.updateMember(edited)
                    }
                }
            }
            .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        updateMemberPhotoURL(AvatarPhotoStore.saveAvatarPhoto(from: image, memberId: memberID))
                    }
                    selectedPhotoItem = nil
                }
            }
            .sheet(isPresented: $showingAvatarPickerSheet) {
                AvatarPickerSheet(
                    onUploadPhoto: {
                        showingPhotoLibrary = true
                    },
                    onSelectSymbol: { symbol in
                        updateMemberAvatarSymbol(symbol)
                    },
                    onRemovePhoto: member?.avatarURL != nil ? {
                        AvatarPhotoStore.deletePhoto(reference: member?.avatarURL)
                        updateMemberPhotoURL(nil)
                    } : nil
                )
            }
        }
    }

    private func headerCard(_ member: TribeMember) -> some View {
        TribeCard {
            HStack(spacing: 14) {
                MemberAvatarView(member: member, size: 62)
                    .onTapGesture {
                        showingAvatarPickerSheet = true
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(member.fullName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(TribeTheme.textPrimary)
                    Text(member.subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(TribeTheme.textSecondary)
                    Button("Edit Photo") {
                        showingAvatarPickerSheet = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TribeTheme.primary)
                }
                Spacer()
            }
        }
    }

    private func rolesCard(_ member: TribeMember) -> some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Roles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TribeTheme.textPrimary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(member.roleBadges, id: \.self) { badge in
                        RoleBadge(title: badge)
                    }
                }
            }
        }
    }

    private func permissionsCard(_ member: TribeMember) -> some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Permissions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TribeTheme.textPrimary)

                ForEach(member.derivedPermissions, id: \.self) { permission in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(TribeTheme.primary)
                        Text(permission)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(TribeTheme.textSecondary)
                    }
                }
            }
        }
    }

    private func locationCard(_ member: TribeMember) -> some View {
        TribeCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location Sharing")
                        .font(.system(size: 16, weight: .semibold))
                    Text(member.isLocationSharingEnabled ? "Enabled" : "Disabled")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(member.isLocationSharingEnabled ? Color.green : Color.red)
                }
                Spacer()
                Image(systemName: member.isLocationSharingEnabled ? "location.fill" : "location.slash.fill")
                    .foregroundStyle(member.isLocationSharingEnabled ? Color.green : Color.red)
            }
        }
    }

    private func contactCard(_ member: TribeMember) -> some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Contact")
                    .font(.system(size: 16, weight: .semibold))

                Text(member.phone ?? "No phone number")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(TribeTheme.textSecondary)

                if member.isDriver, member.phone != nil {
                    Button {
                        // UI-only button.
                    } label: {
                        Text("Call Driver")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(TribeTheme.primary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var activityCard: some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Activity")
                    .font(.system(size: 16, weight: .semibold))
                Text("Completed runs: 12")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(TribeTheme.textSecondary)
                Text("Upcoming trips: 3")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(TribeTheme.textSecondary)
            }
        }
    }

    private func updateMemberPhotoURL(_ photoURL: String?) {
        guard var current = member else { return }
        current.avatarURL = photoURL
        store.updateMember(current)
    }

    private func updateMemberAvatarSymbol(_ symbol: AvatarSymbol?) {
        guard var current = member else { return }
        current.avatarSymbol = symbol
        current.avatarImageName = symbol?.rawValue
        store.updateMember(current)
    }
}

#Preview {
    let store = TribeStore(demoFlow: true)
    return MemberProfileView(store: store, memberID: store.members[0].id)
}
