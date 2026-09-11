// CalendarIllustratedComponents.swift
// Illustrated, family-focused building blocks for the TribeBoard Calendar screen.
// Reuses the shared TribeArt / TribePalette / illustratedPanel system from the Home screen.
// Uses ONLY the provided illustration / avatar / activity artwork sliced into the asset catalog.

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Calendar art catalog
// ─────────────────────────────────────────────────────────────────────────────

enum CalArt {
    /// Large family illustration used on the hero card.
    static let family = "illus_family"

    /// Deterministic avatar asset for a name, choosing from the provided artwork.
    static func avatar(forName name: String, isChild: Bool) -> String {
        let seed = abs(name.hashValue)
        if isChild {
            let pool = TribeArt.childAvatars
            return pool[seed % pool.count]
        } else {
            let pool = [TribeArt.mother, TribeArt.father, TribeArt.grandparent]
            return pool[seed % pool.count]
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Calendar data models
// ─────────────────────────────────────────────────────────────────────────────

enum CalStatus {
    case scheduled
    case live
    case done

    var tint: Color {
        switch self {
        case .scheduled: return TribePalette.primary
        case .live:      return TribePalette.green
        case .done:      return TribePalette.muted
        }
    }

    var label: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .live:      return "Live"
        case .done:      return "Done"
        }
    }
}

struct CalTimelineItem: Identifiable {
    let id: String
    var time: String
    var icon: String
    var iconTint: Color
    var avatar: String?
    var title: String
    var place: String?
    var driver: String?
    var status: CalStatus
}

struct CalUpcomingItem: Identifiable {
    let id: String
    var date: Date
    var dayTitle: String
    var activityCount: Int
    var miniIcons: [String]
    var miniTints: [Color]
    var artwork: String
}

struct CalFeedItem: Identifiable {
    let id: String
    var name: String
    var action: String
    var timeText: String
    var avatar: String
}

struct CalSuggestion: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var systemIcon: String
    var tint: Color
    var soft: Color
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Hero card
// ─────────────────────────────────────────────────────────────────────────────

struct CalHeroCard: View {
    let title: String
    let highlight: String
    let footnote: String
    let allSet: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                TribePalette.primaryGradient

                // Large family illustration, bled toward the right and blended.
                Image(CalArt.family)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width * 0.6, height: geo.size.height, alignment: .bottom)
                    .clipped()
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.28),
                                .init(color: .black, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .allowsHitTesting(false)

                // Soft left scrim keeps text readable over the illustration.
                LinearGradient(
                    stops: [
                        .init(color: Color(tribeHex: "#6D5BD0").opacity(0.55), location: 0.0),
                        .init(color: Color(tribeHex: "#6D5BD0").opacity(0.0), location: 0.62)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .kerning(0.5)

                    Text(highlight)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(allSet ? Color.white : Color(tribeHex: "#FFE08A"))
                            .frame(width: 7, height: 7)
                        Text(footnote)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.18), in: Capsule())
                }
                .padding(20)
                .frame(maxWidth: geo.size.width * 0.62, alignment: .leading)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: TribePalette.primary.opacity(0.25), radius: 16, x: 0, y: 10)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Family suggestions (empty day)
// ─────────────────────────────────────────────────────────────────────────────

struct CalFamilySuggestionsCard: View {
    let dayTitle: String
    let suggestions: [CalSuggestion]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TribePalette.ink)
                Text("A free day — here are a few ideas")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TribePalette.muted)
            }

            VStack(spacing: 10) {
                ForEach(suggestions) { suggestion in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(suggestion.soft)
                                .frame(width: 44, height: 44)
                            Image(systemName: suggestion.systemIcon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(suggestion.tint)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(TribePalette.ink)
                            Text(suggestion.subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(TribePalette.muted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(TribePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.04), lineWidth: 1)
                    }
                }
            }
        }
        .illustratedPanel(cornerRadius: 24, padding: 18)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Timeline row
// ─────────────────────────────────────────────────────────────────────────────

struct CalTimelineRow: View {
    let item: CalTimelineItem
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time + connector rail
            VStack(spacing: 0) {
                Text(item.time)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TribePalette.muted)
                    .frame(width: 54, alignment: .trailing)
            }
            .frame(width: 54, alignment: .trailing)

            VStack(spacing: 0) {
                Circle()
                    .fill(item.status.tint)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                if !isLast {
                    Rectangle()
                        .fill(TribePalette.primary.opacity(0.16))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 11)

            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(item.iconTint).frame(width: 42, height: 42)
                    Image(item.icon).resizable().scaledToFit().frame(width: 24, height: 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TribePalette.ink)
                        .lineLimit(1)
                    if let place = item.place, !place.isEmpty {
                        Text(place)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TribePalette.muted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if let avatar = item.avatar {
                    avatarCircle(avatar, size: 30)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                }
            }
            .padding(.bottom, isLast ? 0 : 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Daily summary row
// ─────────────────────────────────────────────────────────────────────────────

struct CalDailySummaryRow: View {
    let summary: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(TribePalette.primarySoft).frame(width: 38, height: 38)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(TribePalette.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily summary")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TribePalette.ink)
                    Text(summary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TribePalette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TribePalette.muted)
            }
            .illustratedPanel(cornerRadius: 20, padding: 14)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Upcoming card
// ─────────────────────────────────────────────────────────────────────────────

struct CalUpcomingCard: View {
    let item: CalUpcomingItem
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(TribePalette.primarySoft)
                    Image(item.artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.dayTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TribePalette.ink)
                        .lineLimit(1)
                    Text("\(item.activityCount) \(item.activityCount == 1 ? "activity" : "activities") planned")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TribePalette.muted)
                        .lineLimit(1)
                    if !item.miniIcons.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(item.miniIcons.enumerated()), id: \.offset) { idx, icon in
                                ZStack {
                                    Circle()
                                        .fill(idx < item.miniTints.count ? item.miniTints[idx] : TribePalette.primarySoft)
                                        .frame(width: 26, height: 26)
                                    Image(icon).resizable().scaledToFit().frame(width: 16, height: 16)
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TribePalette.muted)
            }
            .illustratedPanel(cornerRadius: 22, padding: 14)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Family feed row
// ─────────────────────────────────────────────────────────────────────────────

struct CalFeedRow: View {
    let item: CalFeedItem

    var body: some View {
        HStack(spacing: 12) {
            avatarCircle(item.avatar, size: 40)
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 2) {
                (
                    Text(item.name).font(.system(size: 14, weight: .bold)).foregroundColor(TribePalette.ink)
                    + Text(" \(item.action)").font(.system(size: 14, weight: .medium)).foregroundColor(TribePalette.muted)
                )
                .lineLimit(2)
                Text(item.timeText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TribePalette.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(TribePalette.green)
        }
    }
}
