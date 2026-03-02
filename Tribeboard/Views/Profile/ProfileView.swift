import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var flow: AppFlowState
    @AppStorage("profile.activeRole") private var activeRoleRawValue = ProfileSessionRole.driver.rawValue
    @State private var showingPhotoOptions = false
    @State private var showingCameraPicker = false
    @State private var showingPhotoLibrary = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    private var activeRole: ProfileSessionRole {
        get { ProfileSessionRole(rawValue: activeRoleRawValue) ?? .driver }
        set { activeRoleRawValue = newValue.rawValue }
    }

    private var currentMember: TribeMember? {
        flow.tribeStore.members.first(where: { $0.memberType == .adult }) ?? flow.tribeStore.members.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerCard
                roleSwitcherCard
                sessionCard
            }
            .padding(16)
        }
        .background(Color(white: 0.97))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    updateCurrentMemberPhotoURL(AvatarPhotoStore.saveAvatarPhoto(from: image, memberId: currentMember?.id ?? UUID()))
                }
                selectedPhotoItem = nil
            }
        }
        .confirmationDialog("Edit Photo", isPresented: $showingPhotoOptions, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    showingCameraPicker = true
                }
            }
            Button("Choose Photo") {
                showingPhotoLibrary = true
            }
            Button("Remove Photo", role: .destructive) {
                    AvatarPhotoStore.deletePhoto(reference: currentMember?.avatarURL)
                    updateCurrentMemberPhotoURL(nil)
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingCameraPicker) {
            CameraImagePicker { image in
                    updateCurrentMemberPhotoURL(AvatarPhotoStore.saveAvatarPhoto(from: image, memberId: currentMember?.id ?? UUID()))
            }
            .ignoresSafeArea()
        }
    }

    private var headerCard: some View {
        VStack(spacing: 10) {
            if let member = currentMember {
                MemberAvatarView(member: member, size: 72)
                    .onTapGesture {
                        showingPhotoOptions = true
                    }
            } else {
                AvatarView(name: "You", identity: "profile-fallback", size: 72)
            }

            Text(currentMember?.fullName ?? "Your Profile")
                .font(.title3.bold())

            HStack(spacing: 8) {
                rolePill("Parent")
                rolePill("Admin")
                rolePill(activeRole.title)
            }
            Button("Edit Photo") {
                showingPhotoOptions = true
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.indigo)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var roleSwitcherCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active Role")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Picker("Active Role", selection: $activeRoleRawValue) {
                ForEach(ProfileSessionRole.allCases, id: \.self) { role in
                    Text(role.title).tag(role.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Session")
            Button(role: .destructive) {
                flow.signOut()
            } label: {
                HStack {
                    Text("Sign Out")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            NavigationLink {
                SettingsView()
            } label: {
                HStack(spacing: 8) {
                    Text("Open Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func rolePill(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.indigo)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.indigo.opacity(0.12))
            .clipShape(Capsule())
    }

    private func updateCurrentMemberPhotoURL(_ photoURL: String?) {
        guard var member = currentMember else { return }
        member.avatarURL = photoURL
        flow.tribeStore.updateMember(member)
    }
}

private enum ProfileSessionRole: String, CaseIterable {
    case driver = "driver"
    case observer = "observer"

    var title: String {
        switch self {
        case .driver:
            return "Driver"
        case .observer:
            return "Observer"
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppFlowState())
    }
}
