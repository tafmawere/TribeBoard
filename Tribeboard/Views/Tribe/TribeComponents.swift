import SwiftUI
import UIKit

enum TribeTheme {
    static let background = Color(red: 0.976, green: 0.980, blue: 0.984) // #F9FAFB
    static let card = Color.white
    static let primary = Color(red: 0.388, green: 0.400, blue: 0.945) // #6366F1
    static let textPrimary = Color(red: 0.098, green: 0.110, blue: 0.145)
    static let textSecondary = Color(red: 0.376, green: 0.451, blue: 0.600)
}

struct TribeCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(TribeTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }
}

struct RoleBadge: View {
    let title: String

    var body: some View {
        AppBadge(text: title, style: .info)
    }
}

struct MemberSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold))
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
}

struct TribeSearchBar: View {
    @Binding var searchText: String
    var placeholder = "Search members by name or role"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TribeTheme.textSecondary)

            TextField(placeholder, text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 5)
    }
}

struct MemberRow: View {
    let member: TribeMember
    var onRowTap: (() -> Void)? = nil
    var onAvatarTap: (() -> Void)? = nil

    private var shouldShowSubtitle: Bool {
        member.memberType == .child
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MemberAvatarView(member: member, size: 46, showsStatus: true)
                .padding(.top, 1)
                .onTapGesture {
                    onAvatarTap?()
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(member.fullName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TribeTheme.textPrimary)

                if shouldShowSubtitle {
                    Text(member.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(TribeTheme.textSecondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(member.roleBadges, id: \.self) { badge in
                            RoleBadge(title: badge)
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
}

struct MemberAvatarView: View {
    enum AvatarSize {
        case small
        case medium
        case large

        var dimension: CGFloat {
            switch self {
            case .small: return 34
            case .medium: return 46
            case .large: return 72
            }
        }
    }

    let member: MemberAvatarData
    let size: CGFloat
    var showCameraBadge: Bool = false
    var onTap: (() -> Void)? = nil
    var showsStatus: Bool = false
    private var isOnline: Bool = false

    init(
        member: TribeMember,
        size: CGFloat = 46,
        showCameraBadge: Bool = false,
        onTap: (() -> Void)? = nil,
        showsStatus: Bool = false
    ) {
        self.member = member.avatar
        self.size = size
        self.showCameraBadge = showCameraBadge
        self.onTap = onTap
        self.showsStatus = showsStatus
        self.isOnline = member.isOnline
    }

    init(
        member: MemberAvatarData,
        size: AvatarSize,
        showCameraBadge: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.member = member
        self.size = size.dimension
        self.showCameraBadge = showCameraBadge
        self.onTap = onTap
    }

    init(
        member: MemberAvatarData,
        size: CGFloat = 46,
        showCameraBadge: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.member = member
        self.size = size
        self.showCameraBadge = showCameraBadge
        self.onTap = onTap
    }

    var body: some View {
        let avatar = baseAvatar
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(Color.white, lineWidth: 1.5)
            }
            .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 2)
            .overlay(alignment: .bottomTrailing) {
                if showCameraBadge {
                    cameraBadge
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showsStatus {
                    onlineStatusDot
                }
            }
            .frame(width: size, height: size)

        Group {
            if let onTap {
                Button(action: onTap) {
                    avatar
                }
                .buttonStyle(.plain)
            } else {
                avatar
            }
        }
    }

    @ViewBuilder
    private var baseAvatar: some View {
        // Priority order is photo, then selected symbol, then initials fallback.
        if let resolvedPhotoURL = AvatarPhotoStore.resolvePhotoURL(from: member.photoURL) {
            if resolvedPhotoURL.isFileURL, let uiImage = UIImage(contentsOfFile: resolvedPhotoURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                AsyncImage(url: resolvedPhotoURL) { phase in
                    switch phase {
                    case .empty:
                        fallbackTinted
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallbackTinted
                    @unknown default:
                        fallbackTinted
                    }
                }
            }
        } else if let symbol = member.symbol ?? AvatarSymbol.fromLegacyImageName(member.imageReference) {
            ZStack {
                Circle().fill(Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.10))
                Image(systemName: symbol.rawValue)
                    .font(.system(size: max(12, size * 0.34), weight: .semibold))
                    .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
            }
        } else {
            fallbackTinted
        }
    }

    private var fallbackTinted: some View {
        ZStack {
            Circle().fill(Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.12))
            Text(member.initials)
                .font(.system(size: max(11, size * 0.30), weight: .bold))
                .foregroundStyle(Color(red: 0.286, green: 0.357, blue: 0.769))
        }
    }

    private var cameraBadge: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.95))
                .frame(width: max(16, size * 0.28), height: max(16, size * 0.28))
            Image(systemName: "camera.fill")
                .font(.system(size: max(7, size * 0.13), weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay {
            Circle().stroke(Color.white, lineWidth: 1.1)
        }
        .offset(x: 1, y: 1)
    }

    private var onlineStatusDot: some View {
        Circle()
            .fill(isOnline ? Color.green : Color.gray.opacity(0.4))
            .frame(width: 10, height: 10)
            .overlay {
                Circle().stroke(Color.white, lineWidth: 1.5)
            }
    }
}

struct AvatarView: View {
    let name: String
    let identity: String
    var avatarSeed: String? = nil
    var avatarURL: String? = nil
    var imageName: String? = nil
    var remoteImageURL: URL? = nil
    var size: CGFloat = 44

    var body: some View {
        MemberAvatarView(
            member: MemberAvatarData(
                photoURL: remoteImageURL?.absoluteString ?? avatarURL,
                imageReference: imageName,
                symbol: AvatarSymbol.fromLegacyImageName(imageName),
                seed: avatarSeed ?? identity,
                name: name
            ),
            size: size
        )
    }
}

struct MemberAvatarStackView: View {
    let members: [TribeMember]
    var maxVisible: Int = 3
    var avatarSize: CGFloat = 26
    var overlap: CGFloat = 8

    var body: some View {
        let visibleMembers = Array(members.prefix(maxVisible))
        let extraCount = max(0, members.count - visibleMembers.count)

        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                ForEach(Array(visibleMembers.enumerated()), id: \.element.id) { index, member in
                    MemberAvatarView(member: member, size: avatarSize)
                        .offset(x: CGFloat(index) * (avatarSize - overlap))
                        .zIndex(Double(visibleMembers.count - index))
                }
            }
            .frame(width: stackWidth(for: visibleMembers.count), height: avatarSize)

            if extraCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.16))
                    Text("+\(extraCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: avatarSize, height: avatarSize)
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 1.5)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                .offset(x: -overlap)
            }
        }
    }

    private func stackWidth(for count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return avatarSize + CGFloat(max(0, count - 1)) * (avatarSize - overlap)
    }
}
