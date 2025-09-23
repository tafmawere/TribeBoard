import SwiftUI

/// Message bubble component for displaying individual family messages
struct MessageBubbleView: View {
    let message: FamilyMessage
    let userProfiles: [UUID: UserProfile]
    let isCurrentUser: Bool
    let onMarkAsRead: () async -> Void
    
    @State private var showingTimestamp = false
    
    private var senderName: String {
        userProfiles[message.sender]?.displayName ?? "Unknown User"
    }
    
    private var messageTypeIcon: String {
        switch message.type {
        case .text:
            return ""
        case .announcement:
            return "📢"
        case .photo:
            return "📷"
        case .reminder:
            return "⏰"
        }
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isCurrentUser {
                // Sender avatar for other users
                MemberAvatarView(userProfile: userProfiles[message.sender])
                    .frame(width: 32, height: 32)
            } else {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name (only for other users)
                if !isCurrentUser {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                }
                
                // Message bubble
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingTimestamp.toggle()
                    }
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Message type indicator
                        if message.type != .text {
                            HStack(spacing: 6) {
                                Text(messageTypeIcon)
                                    .font(.caption)
                                
                                Text(message.type.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .secondary)
                            }
                        }
                        
                        // Message content
                        Text(message.content)
                            .font(.subheadline)
                            .foregroundColor(isCurrentUser ? .white : .primary)
                            .multilineTextAlignment(.leading)
                        
                        // Attachment indicator
                        if message.attachmentUrl != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "paperclip")
                                    .font(.caption)
                                
                                Text("Attachment")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                isCurrentUser ? 
                                AnyShapeStyle(LinearGradient.brandGradient) : 
                                AnyShapeStyle(Color(.systemGray5))
                            )
                    )
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isCurrentUser ? .trailing : .leading)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Timestamp (shown on tap)
                if showingTimestamp {
                    HStack(spacing: 4) {
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        // Read status indicator for current user's messages
                        if isCurrentUser {
                            Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.caption2)
                                .foregroundColor(message.isRead ? .green : .secondary)
                        }
                        
                        // Unread indicator for other users' messages
                        if !isCurrentUser && !message.isRead {
                            Circle()
                                .fill(Color.brandPrimary)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            
            if isCurrentUser {
                // Current user avatar
                MemberAvatarView(userProfile: userProfiles[message.sender])
                    .frame(width: 32, height: 32)
            } else {
                Spacer()
            }
        }
        .onAppear {
            // Mark message as read when it appears (for non-current user messages)
            if !isCurrentUser && !message.isRead {
                Task {
                    await onMarkAsRead()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.type.displayName) from \(senderName): \(message.content)")
        .accessibilityHint("Tap to show timestamp")
    }
}

// MARK: - Preview

#Preview {
    let mockData = MockDataGenerator.mockMawereFamily()
    let mockMessages = MockDataGenerator.mockFamilyMessages()
    let userProfiles = Dictionary(uniqueKeysWithValues: mockData.users.map { ($0.id, $0) })
    
    return VStack(spacing: 16) {
        // Current user message
        MessageBubbleView(
            message: mockMessages[0],
            userProfiles: userProfiles,
            isCurrentUser: true,
            onMarkAsRead: { }
        )
        
        // Other user message
        MessageBubbleView(
            message: mockMessages[1],
            userProfiles: userProfiles,
            isCurrentUser: false,
            onMarkAsRead: { }
        )
        
        // Announcement message
        MessageBubbleView(
            message: FamilyMessage(
                id: UUID(),
                content: "Family meeting tonight at 7 PM in the living room. We'll discuss weekend plans and chore assignments.",
                sender: mockData.users[0].id,
                timestamp: Date(),
                type: .announcement,
                isRead: false,
                attachmentUrl: nil
            ),
            userProfiles: userProfiles,
            isCurrentUser: false,
            onMarkAsRead: { }
        )
    }
    .padding()
}