// HomeIllustratedComponents.swift
// Illustrated, Uber/Apple-Family style building blocks for the TribeBoard Home screen.
// Uses ONLY the provided illustration / avatar / activity artwork sliced into the asset catalog.

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Art catalog
// ─────────────────────────────────────────────────────────────────────────────

enum TribeArt {
    // Avatars
    static let mother = "avatar_mother"
    static let motherDriving = "avatar_mother_driving"
    static let father = "avatar_father"
    static let fatherOTW = "avatar_father_otw"
    static let grandparent = "avatar_grandparent"
    static let boy = "avatar_boy"
    static let boySchool = "avatar_boy_school"
    static let girl = "avatar_girl"
    static let girlOTW = "avatar_girl_otw"

    static let childAvatars = [boy, boySchool, girl, girlOTW]
    static let adultAvatars = [mother, father]

    // Run / map art
    static let runTracking = "run_tracking"
    static let runSchool = "run_school"
    static let runPickup = "run_pickup"
    static let runHome = "run_home"

    // 3D icons
    static let iconHome = "icon_home"
    static let iconSchool = "icon_school"
    static let iconCar = "icon_car"
    static let iconTennis = "icon_tennis"
    static let iconPin = "icon_pin"

    // Activity artwork
    static let activityTennis = "activity_tennis"
    static let activitySoccer = "activity_soccer"
    static let activityPiano = "activity_piano"
    static let activityArt = "activity_art"
    static let activitySwimming = "activity_swimming"
    static let activityBallet = "activity_ballet"
    static let activityRobotics = "activity_robotics"
    static let activityChess = "activity_chess"

    static let allActivities = [
        activityTennis, activitySoccer, activityPiano, activityArt,
        activitySwimming, activityBallet, activityRobotics, activityChess
    ]

    /// Best-matching activity artwork for a free-text title.
    static func activityArtwork(for text: String) -> String {
        let t = text.lowercased()
        if t.contains("tennis") { return activityTennis }
        if t.contains("soccer") || t.contains("football") { return activitySoccer }
        if t.contains("piano") || t.contains("music") { return activityPiano }
        if t.contains("art") || t.contains("paint") || t.contains("draw") { return activityArt }
        if t.contains("swim") { return activitySwimming }
        if t.contains("ballet") || t.contains("dance") { return activityBallet }
        if t.contains("robot") || t.contains("cod") || t.contains("stem") { return activityRobotics }
        if t.contains("chess") { return activityChess }
        let idx = abs(text.hashValue) % allActivities.count
        return allActivities[idx]
    }

    /// Best-matching 3D location icon for a free-text place / activity.
    static func locationIcon(for text: String) -> String {
        let t = text.lowercased()
        if t.contains("school") { return iconSchool }
        if t.contains("home") || t.contains("house") { return iconHome }
        if t.contains("tennis") || t.contains("court") || t.contains("club") { return iconTennis }
        if t.contains("pick") || t.contains("drop") || t.contains("car") || t.contains("driv") || t.contains("way") { return iconCar }
        return iconPin
    }

    /// Deterministic avatar for a member given type + index.
    static func avatar(isChild: Bool, index: Int, driving: Bool, onTheWay: Bool) -> String {
        if isChild {
            let pool = childAvatars
            if onTheWay { return index.isMultiple(of: 2) ? girlOTW : boySchool }
            return pool[abs(index) % pool.count]
        } else {
            if driving { return index.isMultiple(of: 2) ? motherDriving : father }
            if onTheWay { return fatherOTW }
            return index.isMultiple(of: 2) ? mother : father
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Palette helpers
// ─────────────────────────────────────────────────────────────────────────────

enum TribePalette {
    static let primary = Color(tribeHex: "#6D5BD0")
    static let primarySoft = Color(tribeHex: "#EFEBFF")
    static let green = Color(tribeHex: "#16B981")
    static let greenSoft = Color(tribeHex: "#E6F7F0")
    static let orange = Color(tribeHex: "#F59E0B")
    static let orangeSoft = Color(tribeHex: "#FEF1DC")
    static let blue = Color(tribeHex: "#3B82F6")
    static let blueSoft = Color(tribeHex: "#E5EEFE")
    static let pink = Color(tribeHex: "#EC4899")
    static let pinkSoft = Color(tribeHex: "#FCE7F2")
    static let ink = Color(tribeHex: "#1A1A2E")
    static let muted = Color(tribeHex: "#8B88A6")
    static let surface = Color.white
    static let canvas = Color(tribeHex: "#F4F4FB")

    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [Color(tribeHex: "#6D5BD0"), Color(tribeHex: "#8B7BE8")],
                       startPoint: .leading, endPoint: .trailing)
    }
}

extension View {
    /// White rounded panel with a soft shadow.
    func illustratedPanel(cornerRadius: CGFloat = 24, padding: CGFloat? = 16, shadow: Bool = true) -> some View {
        self
            .padding(padding ?? 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TribePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            }
            .shadow(color: shadow ? Color.black.opacity(0.05) : .clear, radius: 14, x: 0, y: 8)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Section header
// ─────────────────────────────────────────────────────────────────────────────

struct HomeSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(TribePalette.ink)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TribePalette.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Hero Live Run
// ─────────────────────────────────────────────────────────────────────────────

struct HeroStat: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
}

struct HeroRunInfo {
    var statusLabel: String
    var isLive: Bool
    var headline: String
    var bannerArt: String
    var destinationName: String?
    var destinationTime: String?
    var stats: [HeroStat]
    var driverName: String?
    var driverRating: String?
    var driverAvatar: String?
    var driverAvatarIdentity: TribeAvatarIdentity?
    var ctaText: String
    var footnote: String?
}

struct HeroRunCard: View {
    let info: HeroRunInfo
    var onPrimary: () -> Void
    var onCall: (() -> Void)? = nil

    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            banner
            headlineBlock
            if !info.stats.isEmpty { statsRow }
            if let driver = info.driverName { driverRow(driver) }
            primaryButton
            if let footnote = info.footnote { footnoteRow(footnote) }
        }
        .illustratedPanel(cornerRadius: 28, padding: 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var banner: some View {
        ZStack(alignment: .topLeading) {
            Image(info.bannerArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 168)
                .frame(maxWidth: .infinity)
                .clipped()
                .background(TribePalette.blueSoft)

            // status pill
            HStack(spacing: 6) {
                Circle()
                    .fill(info.isLive ? TribePalette.green : TribePalette.primary)
                    .frame(width: 7, height: 7)
                    .opacity(info.isLive ? (pulse ? 0.35 : 1) : 1)
                Text(info.statusLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TribePalette.ink)
                    .kerning(0.4)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
            .padding(12)

            // destination chip
            if let dest = info.destinationName {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(TribeArt.iconTennis).resizable().scaledToFit().frame(width: 22, height: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                if let t = info.destinationTime {
                                    Text(t).font(.system(size: 12, weight: .bold)).foregroundStyle(TribePalette.ink)
                                }
                                Text(dest).font(.system(size: 10, weight: .medium)).foregroundStyle(TribePalette.muted)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.7), lineWidth: 1))
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
        .frame(height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var headlineBlock: some View {
        Text(info.headline)
            .font(.system(size: 23, weight: .bold))
            .foregroundStyle(TribePalette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(2)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            ForEach(info.stats) { stat in
                HStack(spacing: 9) {
                    ZStack {
                        Circle().fill(TribePalette.primarySoft).frame(width: 30, height: 30)
                        Image(systemName: stat.icon).font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TribePalette.primary)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(stat.label).font(.system(size: 10, weight: .semibold)).foregroundStyle(TribePalette.muted)
                        Text(stat.value).font(.system(size: 15, weight: .bold)).foregroundStyle(TribePalette.ink)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(TribePalette.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func driverRow(_ driver: String) -> some View {
        HStack(spacing: 10) {
            if let identity = info.driverAvatarIdentity {
                TribeAvatarView(identity: identity, size: .small)
            } else {
                TribeAvatarView(displayName: driver, size: .small)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(driver).font(.system(size: 14, weight: .semibold)).foregroundStyle(TribePalette.ink)
                if let rating = info.driverRating {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(TribePalette.orange)
                        Text(rating).font(.system(size: 12, weight: .semibold)).foregroundStyle(TribePalette.muted)
                    }
                }
            }
            Spacer()
            if let onCall {
                Button(action: onCall) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TribePalette.green)
                        .frame(width: 40, height: 40)
                        .background(TribePalette.greenSoft, in: Circle())
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
    }

    private var primaryButton: some View {
        Button(action: onPrimary) {
            HStack(spacing: 8) {
                Text(info.ctaText).font(.system(size: 16, weight: .bold))
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(TribePalette.primaryGradient, in: Capsule())
            .shadow(color: TribePalette.primary.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func footnoteRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(TribePalette.green).frame(width: 6, height: 6)
            Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(TribePalette.muted)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Family status
// ─────────────────────────────────────────────────────────────────────────────

struct FamilyStatusEntry: Identifiable {
    let id: UUID
    var name: String
    var avatarIdentity: TribeAvatarIdentity
    var status: TribeAvatarStatus
    var statusTitle: String
    var detail: String
    var accentIcon: String
}

struct FamilyStatusChip: View {
    let entry: FamilyStatusEntry
    var accessToken: String? = nil
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                TribeAvatarView(
                    identity: entry.avatarIdentity,
                    size: .medium,
                    status: entry.status,
                    accessToken: accessToken
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(TribePalette.ink)
                        .lineLimit(1)
                    Text(entry.statusTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(entry.status.ringColor)
                        .lineLimit(1)
                    Text(entry.detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TribePalette.muted)
                        .lineLimit(1)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(entry.status.ringColor.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(entry.accentIcon).resizable().scaledToFit().frame(width: 18, height: 18)
                }
            }
            .frame(width: 120, alignment: .leading)
            .illustratedPanel(cornerRadius: 20, padding: 12)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

// Illustration-only helper for decorative artwork assets (not member avatars).
func avatarCircle(_ asset: String, size: CGFloat) -> some View {
    Image(asset)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: size, height: size)
        .background(TribePalette.canvas)
        .clipShape(Circle())
}

struct AddChildChip: View {
    var onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(TribePalette.primarySoft).frame(width: 46, height: 46)
                    Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(TribePalette.primary)
                }
                Text("Add\nChild")
                    .font(.system(size: 13, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TribePalette.primary)
            }
            .frame(width: 120, height: 150)
            .background(TribePalette.primarySoft.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .foregroundStyle(TribePalette.primary.opacity(0.4))
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Today's Journey timeline
// ─────────────────────────────────────────────────────────────────────────────

enum JourneyState { case done, live, upcoming }

struct JourneyStop: Identifiable {
    let id: UUID
    var time: String
    var title: String
    var subtitle: String
    var icon: String
    var state: JourneyState

    var ringColor: Color {
        switch state {
        case .done: return TribePalette.green
        case .live: return TribePalette.primary
        case .upcoming: return TribePalette.muted.opacity(0.4)
        }
    }
}

struct JourneyTimelineView: View {
    let stops: [JourneyStop]
    private let nodeWidth: CGFloat = 86

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 8) {
                // times
                HStack(spacing: 0) {
                    ForEach(stops) { stop in
                        Text(stop.time)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(stop.state == .upcoming ? TribePalette.muted : TribePalette.ink)
                            .frame(width: nodeWidth)
                    }
                }
                // icon row + connector
                ZStack {
                    if stops.count > 1 {
                        Rectangle()
                            .fill(TribePalette.primary.opacity(0.18))
                            .frame(height: 3)
                            .padding(.horizontal, nodeWidth / 2)
                    }
                    HStack(spacing: 0) {
                        ForEach(stops) { stop in
                            iconNode(stop).frame(width: nodeWidth)
                        }
                    }
                }
                // labels
                HStack(spacing: 0) {
                    ForEach(stops) { stop in
                        VStack(spacing: 2) {
                            Text(stop.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(TribePalette.ink)
                                .lineLimit(1)
                            Text(stop.subtitle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(stop.state == .live ? TribePalette.primary : TribePalette.muted)
                                .lineLimit(1)
                            stateMark(stop.state).padding(.top, 1)
                        }
                        .frame(width: nodeWidth)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func iconNode(_ stop: JourneyStop) -> some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(Color.white)
                .frame(width: 54, height: 54)
                .overlay(Circle().stroke(stop.ringColor, lineWidth: stop.state == .upcoming ? 2 : 3))
                .overlay {
                    Image(stop.icon).resizable().scaledToFit().frame(width: 30, height: 30).padding(4)
                }
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)

            if stop.state == .live {
                Text("LIVE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(TribePalette.primary, in: Capsule())
                    .offset(y: -10)
            }
        }
        .frame(height: 64, alignment: .top)
    }

    @ViewBuilder
    private func stateMark(_ state: JourneyState) -> some View {
        switch state {
        case .done:
            Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(TribePalette.green)
        case .live:
            Circle().fill(TribePalette.primary).frame(width: 8, height: 8)
        case .upcoming:
            Circle().fill(TribePalette.muted.opacity(0.35)).frame(width: 8, height: 8)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Activities carousel
// ─────────────────────────────────────────────────────────────────────────────

struct ActivityEntry: Identifiable {
    let id: UUID
    var title: String
    var timeText: String
    var statusText: String?
    var statusColor: Color
    var art: String
    var tint: Color
}

struct ActivityChip: View {
    let entry: ActivityEntry
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    TribePalette.surface
                    Image(entry.art)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(8)
                    if let status = entry.statusText {
                        Text(status.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(entry.statusColor, in: Capsule())
                            .padding(8)
                    }
                }
                .frame(width: 168, height: 108)
                .clipped()

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(TribePalette.ink)
                        .lineLimit(1)
                    Text(entry.timeText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TribePalette.muted)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
            }
            .frame(width: 168)
            .background(TribePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.black.opacity(0.04), lineWidth: 1) }
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Quick actions
// ─────────────────────────────────────────────────────────────────────────────

struct QuickActionItem: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var systemIcon: String
    var tint: Color
    var softTint: Color
    var action: () -> Void
}

struct QuickActionTile: View {
    let item: QuickActionItem
    var body: some View {
        Button(action: item.action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(item.tint).frame(width: 42, height: 42)
                    Image(systemName: item.systemIcon).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.system(size: 14, weight: .bold)).foregroundStyle(TribePalette.ink).lineLimit(1)
                    Text(item.subtitle).font(.system(size: 11, weight: .medium)).foregroundStyle(TribePalette.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(item.softTint)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
