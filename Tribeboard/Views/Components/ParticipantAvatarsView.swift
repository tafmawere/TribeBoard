//
//  ParticipantAvatarsView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Horizontal stack of participant avatars with overflow indicator
/// Displays up to 4 avatars with overlapping layout and "+N" for additional participants
/// **Validates: Requirements 3.10**
struct ParticipantAvatarsView: View {
    let participants: [User]
    let maxVisible: Int = 4
    
    private var visibleParticipants: [User] {
        Array(participants.prefix(maxVisible))
    }
    
    private var overflowCount: Int {
        max(0, participants.count - maxVisible)
    }
    
    var body: some View {
        HStack(spacing: -8) {
            ForEach(visibleParticipants) { participant in
                ParticipantAvatar(participant: participant)
            }
            
            if overflowCount > 0 {
                OverflowIndicator(count: overflowCount)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }
    
    private var accessibilityDescription: String {
        if participants.isEmpty {
            return "No participants"
        } else if participants.count <= maxVisible {
            let names = participants.map { $0.displayName }.joined(separator: ", ")
            return "Participants: \(names)"
        } else {
            let visibleNames = visibleParticipants.map { $0.displayName }.joined(separator: ", ")
            return "Participants: \(visibleNames), and \(overflowCount) more"
        }
    }
}

// MARK: - Participant Avatar

private struct ParticipantAvatar: View {
    let participant: User
    
    @Environment(\.colorScheme) var colorScheme
    
    private var borderColor: Color {
        colorScheme == .dark ? Color(.systemGray5) : .white
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(borderColor)
                .frame(width: 32, height: 32)
            
            if let avatarURL = participant.avatarURL, !avatarURL.isEmpty {
                AsyncImage(url: URL(string: avatarURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    case .failure, .empty:
                        DefaultAvatarView(displayName: participant.displayName)
                    @unknown default:
                        DefaultAvatarView(displayName: participant.displayName)
                    }
                }
            } else {
                DefaultAvatarView(displayName: participant.displayName)
            }
        }
        .overlay(
            Circle()
                .stroke(borderColor, lineWidth: 2)
        )
    }
}

// MARK: - Default Avatar View

private struct DefaultAvatarView: View {
    let displayName: String
    
    private var initials: String {
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
    
    var body: some View {
        Circle()
            .fill(DesignSystem.Colors.primaryBrand.opacity(0.2))
            .frame(width: 28, height: 28)
            .overlay(
                Text(initials)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryBrand)
            )
    }
}

// MARK: - Overflow Indicator

private struct OverflowIndicator: View {
    let count: Int
    
    @Environment(\.colorScheme) var colorScheme
    
    private var borderColor: Color {
        colorScheme == .dark ? Color(.systemGray5) : .white
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(borderColor)
                .frame(width: 32, height: 32)
            
            Circle()
                .fill(Color(.secondarySystemFill))
                .frame(width: 28, height: 28)
                .overlay(
                    Text("+\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                )
        }
        .overlay(
            Circle()
                .stroke(borderColor, lineWidth: 2)
        )
    }
}

// MARK: - Previews

#Preview("Empty Participants") {
    ParticipantAvatarsView(participants: [])
        .padding()
}

#Preview("Single Participant") {
    ParticipantAvatarsView(participants: [
        User(id: "1", displayName: "John Doe", role: .driver, familyId: "fam1")
    ])
    .padding()
}

#Preview("Four Participants") {
    ParticipantAvatarsView(participants: [
        User(id: "1", displayName: "John Doe", role: .driver, familyId: "fam1"),
        User(id: "2", displayName: "Jane Smith", role: .admin, familyId: "fam1"),
        User(id: "3", displayName: "Alice Johnson", role: .observer, familyId: "fam1"),
        User(id: "4", displayName: "Bob Wilson", role: .observer, familyId: "fam1")
    ])
    .padding()
}

#Preview("With Overflow") {
    ParticipantAvatarsView(participants: [
        User(id: "1", displayName: "John Doe", role: .driver, familyId: "fam1"),
        User(id: "2", displayName: "Jane Smith", role: .admin, familyId: "fam1"),
        User(id: "3", displayName: "Alice Johnson", role: .observer, familyId: "fam1"),
        User(id: "4", displayName: "Bob Wilson", role: .observer, familyId: "fam1"),
        User(id: "5", displayName: "Charlie Brown", role: .observer, familyId: "fam1"),
        User(id: "6", displayName: "Diana Prince", role: .observer, familyId: "fam1")
    ])
    .padding()
}

#Preview("Ten Participants") {
    ParticipantAvatarsView(participants: [
        User(id: "1", displayName: "John Doe", role: .driver, familyId: "fam1"),
        User(id: "2", displayName: "Jane Smith", role: .admin, familyId: "fam1"),
        User(id: "3", displayName: "Alice Johnson", role: .observer, familyId: "fam1"),
        User(id: "4", displayName: "Bob Wilson", role: .observer, familyId: "fam1"),
        User(id: "5", displayName: "Charlie Brown", role: .observer, familyId: "fam1"),
        User(id: "6", displayName: "Diana Prince", role: .observer, familyId: "fam1"),
        User(id: "7", displayName: "Eve Adams", role: .observer, familyId: "fam1"),
        User(id: "8", displayName: "Frank Miller", role: .driver, familyId: "fam1"),
        User(id: "9", displayName: "Grace Lee", role: .admin, familyId: "fam1"),
        User(id: "10", displayName: "Henry Ford", role: .observer, familyId: "fam1")
    ])
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        ParticipantAvatarsView(participants: [
            User(id: "1", displayName: "John Doe", role: .driver, familyId: "fam1"),
            User(id: "2", displayName: "Jane Smith", role: .admin, familyId: "fam1"),
            User(id: "3", displayName: "Alice Johnson", role: .observer, familyId: "fam1"),
            User(id: "4", displayName: "Bob Wilson", role: .observer, familyId: "fam1"),
            User(id: "5", displayName: "Charlie Brown", role: .observer, familyId: "fam1")
        ])
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
