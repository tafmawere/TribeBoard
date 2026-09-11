// TodayRunsCardView.swift
// Card showing today's scheduled school runs with status badges.

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Model
// ─────────────────────────────────────────────────────────────────────────────

enum RunStatus {
    case needsSetup, ready, inProgress, completed

    var label: String {
        switch self {
        case .needsSetup:  return "Set up"
        case .ready:       return "Ready"
        case .inProgress:  return "Live"
        case .completed:   return "Done"
        }
    }

    var badgeBg: Color {
        switch self {
        case .needsSetup:  return Color(tribeHex: "#EEF0FF")
        case .ready:       return Color(tribeHex: "#F0FFF4")
        case .inProgress:  return Color(tribeHex: "#FEF3C7")
        case .completed:   return Color(tribeHex: "#F1F5F9")
        }
    }

    var badgeText: Color {
        switch self {
        case .needsSetup:  return Color(tribeHex: "#5B6BE5")
        case .ready:       return Color(tribeHex: "#16A34A")
        case .inProgress:  return Color(tribeHex: "#B45309")
        case .completed:   return Color(tribeHex: "#64748B")
        }
    }

    var iconBg: Color { badgeBg }
}

struct RunItem: Identifiable {
    let id: String
    let name: String
    let time: String
    let location: String?
    let status: RunStatus
    let emoji: String
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Card View
// ─────────────────────────────────────────────────────────────────────────────

struct TodayRunsCardView: View {
    let runs: [RunItem]
    var onSeeAll: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Today's Runs")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.tribeText)
                Spacer()
                if let onSeeAll {
                    Button("See all →", action: onSeeAll)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.tribeIndigo)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if runs.isEmpty {
                EmptyRunsState()
            } else {
                ForEach(Array(runs.enumerated()), id: \.element.id) { index, run in
                    if index > 0 {
                        Divider()
                            .background(Color(tribeHex: "#F0EEF8"))
                            .padding(.leading, 66)
                    }
                    RunRow(run: run)
                }
            }
        }
        .background(Color.tribeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.tribeBorder, lineWidth: 0.5)
        )
        .shadow(color: Color.tribeIndigo.opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Sub-views
// ─────────────────────────────────────────────────────────────────────────────

private struct RunRow: View {
    let run: RunItem

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(run.status.iconBg)
                    .frame(width: 38, height: 38)
                Text(run.emoji).font(.system(size: 18))
            }
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(run.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.tribeText)
                Text([run.time, run.location].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.tribeMuted)
            }
            Spacer()
            // Badge
            Text(run.status.label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(run.status.badgeText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(run.status.badgeBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct EmptyRunsState: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("🚗").font(.system(size: 32))
            Text("No runs scheduled yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.tribeText)
            Text("Tap \"Create Run\" below to get started")
                .font(.system(size: 12))
                .foregroundStyle(Color.tribeMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────────────────────────────────────

#Preview {
    ScrollView {
        TodayRunsCardView(
            runs: [
                RunItem(id: "1", name: "Morning Drop-off", time: "7:30 AM",
                        location: nil, status: .needsSetup, emoji: "🏫"),
                RunItem(id: "2", name: "Soccer Pickup", time: "3:45 PM",
                        location: "Riverside Fields", status: .ready, emoji: "⚽"),
            ],
            onSeeAll: {}
        )
    }
    .background(Color.tribeBg)
}
