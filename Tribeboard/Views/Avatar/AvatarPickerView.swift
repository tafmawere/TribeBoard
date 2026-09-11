import SwiftUI
import PhotosUI

enum AvatarSubjectKind {
    case profile(UUID)
    case child(UUID)
}

struct AvatarPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext

    let subjectKind: AvatarSubjectKind
    let displayName: String
    let memberType: MemberType
    let isDriver: Bool
    let canUploadPhoto: Bool
    let initialIdentity: TribeAvatarIdentity
    let accessToken: String
    var onSaved: ((TribeAvatarIdentity) -> Void)?

    @State private var selectedKey: String?
    @State private var selectedType: AvatarType
    @State private var selectedUploadedPath: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var inlineError: String?
    @State private var showCamera = false
    @State private var pendingUploadData: Data?

    init(
        subjectKind: AvatarSubjectKind,
        displayName: String,
        memberType: MemberType = .adult,
        isDriver: Bool = false,
        canUploadPhoto: Bool = true,
        initialIdentity: TribeAvatarIdentity,
        accessToken: String,
        onSaved: ((TribeAvatarIdentity) -> Void)? = nil
    ) {
        self.subjectKind = subjectKind
        self.displayName = displayName
        self.memberType = memberType
        self.isDriver = isDriver
        self.canUploadPhoto = canUploadPhoto
        self.initialIdentity = initialIdentity
        self.accessToken = accessToken
        self.onSaved = onSaved
        _selectedType = State(initialValue: initialIdentity.avatarType)
        _selectedKey = State(initialValue: initialIdentity.avatarKey)
        _selectedUploadedPath = State(initialValue: initialIdentity.avatarURL)
    }

    private var isChildProfile: Bool { memberType == .child }

    private var sectionTitle: String {
        isChildProfile ? "Child profile image" : "Profile picture"
    }

    private var sectionSubtitle: String {
        if isChildProfile {
            return "Use an illustrated avatar by default, or upload a photo if you prefer."
        }
        return "Choose a TribeBoard avatar or upload your own photo."
    }

    private var previewIdentity: TribeAvatarIdentity {
        TribeAvatarIdentity(
            avatarType: selectedType,
            avatarKey: selectedKey,
            avatarURL: selectedUploadedPath,
            displayName: displayName
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerPreview

                Text(sectionSubtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                if let inlineError {
                    Text(inlineError)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }

                presetSections

                if canUploadPhoto {
                    uploadSection
                }

                if selectedType == .uploaded || selectedKey != nil {
                    removeSection
                }
            }
            .padding(20)
        }
        .navigationTitle(sectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(isSaving)
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker { image in
                if let data = prepareAvatarJPEGData(from: image) {
                    pendingUploadData = data
                    selectedType = .uploaded
                }
            }
        }
    }

    private var headerPreview: some View {
        HStack(spacing: 16) {
            TribeAvatarView(
                identity: previewIdentity,
                size: .hero,
                accessToken: accessToken
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 20, weight: .bold))
                Text(selectedType == .preset ? "TribeBoard avatar" : "Uploaded photo")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var presetSections: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose TribeBoard avatar")
                .font(.system(size: 16, weight: .semibold))

            ForEach(filteredGroupedSections, id: \.group.id) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section.group.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
                        ForEach(section.options) { option in
                            presetTile(option)
                        }
                    }
                }
            }
        }
    }

    private var filteredGroupedSections: [(group: AvatarPresetGroup, options: [AvatarPresetOption])] {
        let allowedKeys = Set(AvatarPresetCatalog.options(for: memberType, isDriver: isDriver).map(\.key))
        return AvatarPresetCatalog.groupedSections.compactMap { section in
            let filtered = section.options.filter { allowedKeys.contains($0.key) }
            guard !filtered.isEmpty else { return nil }
            return (section.group, filtered)
        }
    }

    private func presetTile(_ option: AvatarPresetOption) -> some View {
        let isSelected = selectedType == .preset && selectedKey == option.key
        return Button {
            selectedType = .preset
            selectedKey = option.key
            pendingUploadData = nil
        } label: {
            Image(option.assetName)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(isSelected ? TribeAvatarStyle.accent : Color.clear, lineWidth: 3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.key.replacingOccurrences(of: "_", with: " "))
    }

    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upload photo")
                .font(.system(size: 16, weight: .semibold))

            HStack(spacing: 12) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose from library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showCamera = true
                } label: {
                    Label("Take photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var removeSection: some View {
        Button(role: .destructive) {
            selectedType = .preset
            selectedKey = AvatarPresetCatalog.defaultKey(for: memberType)
            selectedUploadedPath = nil
            pendingUploadData = nil
        } label: {
            Label("Remove photo / use default avatar", systemImage: "arrow.counterclockwise")
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let jpeg = prepareAvatarJPEGData(from: image) {
                pendingUploadData = jpeg
                selectedType = .uploaded
            }
        } catch {
            inlineError = "Could not load that photo."
        }
    }

    private func save() async {
        inlineError = nil
        isSaving = true
        defer { isSaving = false }

        let service = AvatarBackendService()
        do {
            var finalType = selectedType
            var finalKey = selectedKey ?? AvatarPresetCatalog.defaultKey(for: memberType)
            var finalURL: String? = selectedUploadedPath

            if let pendingUploadData {
                let profileId: UUID
                switch subjectKind {
                case .profile(let id):
                    profileId = id
                case .child(let id):
                    profileId = id
                }
                finalURL = try await service.uploadProfilePhoto(
                    profileId: profileId,
                    imageData: pendingUploadData,
                    accessToken: accessToken
                )
                finalType = .uploaded
            }

            let patch = AvatarBackendService.makePatch(
                avatarType: finalType,
                avatarKey: finalType == .preset ? finalKey : nil,
                avatarURL: finalType == .uploaded ? finalURL : nil
            )

            switch subjectKind {
            case .profile(let profileId):
                try await service.patchProfileAvatar(profileId: profileId, patch: patch, accessToken: accessToken)
                await backendProfileContext.refreshProfile()
            case .child(let childId):
                try await service.patchChildAvatar(childId: childId, patch: patch, accessToken: accessToken)
                if let householdId = backendHouseholdContext.activeHouseholdId {
                    await backendChildrenContext.refreshChildren(householdId: householdId)
                }
            }

            let saved = TribeAvatarIdentity(
                avatarType: finalType,
                avatarKey: finalType == .preset ? finalKey : nil,
                avatarURL: finalType == .uploaded ? finalURL : nil,
                displayName: displayName
            )
            onSaved?(saved)
            dismiss()
        } catch {
            inlineError = error.localizedDescription
        }
    }
}
