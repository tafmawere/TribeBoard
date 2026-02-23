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
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(TribeTheme.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(TribeTheme.primary.opacity(0.12))
            .clipShape(Capsule())
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

    private var initials: String {
        let pieces = member.fullName.split(separator: " ")
        let chars = pieces.prefix(2).compactMap { $0.first }.map { String($0) }
        return chars.joined().uppercased()
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

                Text(member.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(TribeTheme.textSecondary)

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
    let member: TribeMember
    var size: CGFloat = 46
    var showsStatus: Bool = false

    private var initials: String {
        let pieces = member.fullName.split(separator: " ")
        let chars = pieces.prefix(2).compactMap { $0.first }.map { String($0) }
        return chars.joined().uppercased()
    }

    private var fallbackBackground: Color {
        let palette: [Color] = [
            Color(red: 0.388, green: 0.400, blue: 0.945),
            Color(red: 0.180, green: 0.588, blue: 0.796),
            Color(red: 0.584, green: 0.400, blue: 0.933),
            Color(red: 0.949, green: 0.412, blue: 0.357),
            Color(red: 0.243, green: 0.705, blue: 0.482),
            Color(red: 0.941, green: 0.612, blue: 0.180)
        ]
        let hash = member.id.uuidString.unicodeScalars.reduce(0) { partialResult, scalar in
            (partialResult &* 31 &+ Int(scalar.value))
        }
        let index = abs(hash) % palette.count
        return palette[index]
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarContent
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 1.5)
                }
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)

            if showsStatus {
                Circle()
                    .fill(member.isOnline ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle().stroke(Color.white, lineWidth: 1.5)
                    }
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let url = member.profileImageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        fallbackBackground.opacity(0.24)
                        ProgressView()
                            .tint(fallbackBackground)
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackAvatar
                @unknown default:
                    fallbackAvatar
                }
            }
        } else {
            fallbackAvatar
        }
    }

    private var fallbackAvatar: some View {
        ZStack {
            fallbackBackground.opacity(0.22)
            Text(initials)
                .font(.system(size: max(12, size * 0.32), weight: .bold))
                .foregroundStyle(fallbackBackground)
        }
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
