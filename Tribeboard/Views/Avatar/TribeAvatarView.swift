import SwiftUI

struct TribeAvatarView: View {
    let identity: TribeAvatarIdentity
    var size: TribeAvatarSize = .medium
    var status: TribeAvatarStatus? = nil
    var showCameraBadge: Bool = false
    var showsStatus: Bool = false
    var isOnline: Bool = false
    var accessToken: String? = nil
    var onTap: (() -> Void)? = nil

    @State private var resolvedUploadedURL: URL?
    @State private var uploadedLoadFailed = false

    private var dimension: CGFloat { size.dimension }

    private var resolvedStatus: TribeAvatarStatus? {
        if let status { return status }
        if showsStatus, isOnline { return .available }
        return nil
    }

    var body: some View {
        let avatar = avatarContent
            .frame(width: dimension, height: dimension)
            .clipShape(Circle())
            .background(Circle().fill(TribeAvatarStyle.fallbackBackground))
            .overlay {
                Circle().stroke(TribeAvatarStyle.borderColor, lineWidth: size.borderWidth)
            }
            .overlay {
                if let resolvedStatus {
                    Circle().stroke(resolvedStatus.ringColor.opacity(0.5), lineWidth: size.statusRingWidth)
                }
            }
            .shadow(
                color: TribeAvatarStyle.shadowColor,
                radius: size.shadowRadius,
                x: 0,
                y: size.shadowYOffset
            )
            .overlay(alignment: .topTrailing) {
                if let resolvedStatus {
                    statusIndicator(for: resolvedStatus)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showCameraBadge {
                    cameraBadge
                }
            }
            .frame(width: dimension, height: dimension)
            .task(id: uploadResolutionTaskID) {
                await resolveUploadedURLIfNeeded()
            }

        Group {
            if let onTap {
                Button(action: onTap) { avatar }.buttonStyle(.plain)
            } else {
                avatar
            }
        }
    }

    private var uploadResolutionTaskID: String {
        "\(identity.avatarType.rawValue)|\(identity.avatarURL ?? "")|\(accessToken?.prefix(8) ?? "")"
    }

    @ViewBuilder
    private var avatarContent: some View {
        switch identity.avatarType {
        case .preset:
            presetContent
        case .uploaded:
            uploadedContent
        }
    }

    @ViewBuilder
    private var presetContent: some View {
        let assetName = AvatarPresetCatalog.assetName(
            for: identity.avatarKey ?? AvatarPresetCatalog.defaultAdultKey
        )
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFill()
        } else {
            initialsFallback
        }
    }

    @ViewBuilder
    private var uploadedContent: some View {
        if uploadedLoadFailed {
            initialsFallback
        } else if let resolvedUploadedURL {
            AsyncImage(url: resolvedUploadedURL) { phase in
                switch phase {
                case .empty:
                    initialsFallback
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    initialsFallback
                        .onAppear { uploadedLoadFailed = true }
                @unknown default:
                    initialsFallback
                }
            }
        } else if let localURL = AvatarPhotoStore.resolvePhotoURL(from: identity.avatarURL),
                  localURL.isFileURL,
                  let uiImage = UIImage(contentsOfFile: localURL.path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let directURL = identity.avatarURL,
                  directURL.hasPrefix("http"),
                  let url = URL(string: directURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    initialsFallback
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    initialsFallback
                        .onAppear { uploadedLoadFailed = true }
                @unknown default:
                    initialsFallback
                }
            }
        } else {
            initialsFallback
        }
    }

    private var initialsFallback: some View {
        ZStack {
            Circle().fill(TribeAvatarStyle.fallbackBackground)
            Text(identity.initials)
                .font(.system(size: size.initialsFontSize, weight: .bold))
                .foregroundStyle(TribeAvatarStyle.initialsForeground)
        }
    }

    private func statusIndicator(for status: TribeAvatarStatus) -> some View {
        Circle()
            .fill(status.ringColor)
            .frame(width: size.statusDotSize, height: size.statusDotSize)
            .overlay {
                Circle().stroke(Color.white, lineWidth: size.statusDotStrokeWidth)
            }
            .offset(x: 2, y: -2)
    }

    private var cameraBadge: some View {
        ZStack {
            Circle()
                .fill(TribeAvatarStyle.accent)
                .frame(width: max(16, dimension * 0.28), height: max(16, dimension * 0.28))
            Image(systemName: "camera.fill")
                .font(.system(size: max(7, dimension * 0.13), weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay {
            Circle().stroke(Color.white, lineWidth: 1.1)
        }
        .offset(x: 1, y: 1)
    }

    private func resolveUploadedURLIfNeeded() async {
        uploadedLoadFailed = false
        guard identity.avatarType == .uploaded else {
            resolvedUploadedURL = nil
            return
        }
        resolvedUploadedURL = await AvatarURLResolver.resolveUploadedURL(
            identity.avatarURL,
            accessToken: accessToken
        )
    }
}

enum TribeAvatarStyle {
    static let accent = Color(red: 0.388, green: 0.400, blue: 0.945)
    static let fallbackBackground = Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.12)
    static let initialsForeground = Color(red: 0.286, green: 0.357, blue: 0.769)
    static let borderColor = Color.white
    static let shadowColor = Color.black.opacity(0.10)
}

extension TribeAvatarView {
    init(
        member: TribeMember,
        size: TribeAvatarSize = .medium,
        status: TribeAvatarStatus? = nil,
        showCameraBadge: Bool = false,
        showsStatus: Bool = false,
        accessToken: String? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.init(
            identity: member.avatarIdentity,
            size: size,
            status: status,
            showCameraBadge: showCameraBadge,
            showsStatus: showsStatus,
            isOnline: member.isOnline,
            accessToken: accessToken,
            onTap: onTap
        )
    }

    init(
        member: TribeMember,
        size: CGFloat,
        status: TribeAvatarStatus? = nil,
        showCameraBadge: Bool = false,
        showsStatus: Bool = false,
        accessToken: String? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.init(
            member: member,
            size: TribeAvatarSize.closest(to: size),
            status: status,
            showCameraBadge: showCameraBadge,
            showsStatus: showsStatus,
            accessToken: accessToken,
            onTap: onTap
        )
    }

    init(
        displayName: String,
        size: TribeAvatarSize = .medium,
        accessToken: String? = nil
    ) {
        self.init(
            identity: TribeAvatarIdentity(displayName: displayName),
            size: size,
            accessToken: accessToken
        )
    }
}

extension TribeAvatarSize {
    static func closest(to dimension: CGFloat) -> TribeAvatarSize {
        let all: [TribeAvatarSize] = [.compact, .small, .medium, .large, .hero]
        return all.min(by: { abs($0.dimension - dimension) < abs($1.dimension - dimension) }) ?? .medium
    }
}
