import SwiftUI

/// Noticeboard card component for displaying family announcements and posts
struct NoticeboardCardView: View {
    let post: NoticeboardPost
    let userProfiles: [UUID: UserProfile]
    let canEdit: Bool
    let onEdit: (NoticeboardPost) async -> Void
    let onDelete: () async -> Void
    
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var isExpanded = false
    
    private var authorName: String {
        userProfiles[post.authorId]?.displayName ?? "Unknown User"
    }
    
    private var shouldTruncateContent: Bool {
        post.content.count > 200
    }
    
    private var displayContent: String {
        if shouldTruncateContent && !isExpanded {
            return String(post.content.prefix(200)) + "..."
        }
        return post.content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with author info and actions
            HStack(alignment: .top, spacing: 12) {
                // Author avatar
                MemberAvatarView(userProfile: userProfiles[post.authorId])
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title with pin indicator
                    HStack(spacing: 8) {
                        if post.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Text(post.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Author and timestamp
                    HStack(spacing: 8) {
                        Text(authorName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(post.timestamp, style: .relative)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Unread indicator
                        if !post.isRead {
                            Circle()
                                .fill(Color.brandPrimary)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                
                Spacer()
                
                // Action menu
                if canEdit {
                    Menu {
                        Button("Edit Post") {
                            showingEditSheet = true
                        }
                        
                        Button("Delete Post", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                Text(displayContent)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                // Expand/collapse button for long content
                if shouldTruncateContent {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Text(isExpanded ? "Show Less" : "Show More")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.brandPrimary)
                    }
                }
                
                // Attachment indicator
                if post.attachmentUrl != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "paperclip")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Attachment")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("View") {
                            // Handle attachment viewing
                        }
                        .font(.caption)
                        .foregroundColor(.brandPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            // Footer with interaction options
            HStack(spacing: 20) {
                // Like/reaction placeholder
                Button(action: {
                    // Handle like action
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.subheadline)
                        
                        Text("Like")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Comment placeholder
                Button(action: {
                    // Handle comment action
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.subheadline)
                        
                        Text("Comment")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Share button
                Button(action: {
                    // Handle share action
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingEditSheet) {
            NoticeboardEditSheet(
                post: post,
                onSave: { updatedPost in
                    await onEdit(updatedPost)
                    showingEditSheet = false
                }
            )
        }
        .confirmationDialog(
            "Delete Post",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await onDelete()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(post.title)'? This action cannot be undone.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Post by \(authorName): \(post.title)")
        .accessibilityValue(post.content)
    }
}

// MARK: - Noticeboard Edit Sheet

struct NoticeboardEditSheet: View {
    let post: NoticeboardPost
    let onSave: (NoticeboardPost) async -> Void
    
    @State private var title: String
    @State private var content: String
    @State private var isPinned: Bool
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss
    
    init(post: NoticeboardPost, onSave: @escaping (NoticeboardPost) async -> Void) {
        self.post = post
        self.onSave = onSave
        self._title = State(initialValue: post.title)
        self._content = State(initialValue: post.content)
        self._isPinned = State(initialValue: post.isPinned)
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Post Details") {
                    TextField("Title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Content", text: $content, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(5...10)
                }
                
                Section("Options") {
                    Toggle("Pin to Top", isOn: $isPinned)
                }
            }
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await savePost()
                        }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
        }
    }
    
    private func savePost() async {
        isSaving = true
        
        let updatedPost = NoticeboardPost(
            id: post.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            authorId: post.authorId,
            timestamp: post.timestamp,
            isPinned: isPinned,
            isRead: post.isRead,
            attachmentUrl: post.attachmentUrl
        )
        
        await onSave(updatedPost)
        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    let mockData = MockDataGenerator.mockMawereFamily()
    let mockPosts = MockDataGenerator.mockNoticeboardPosts()
    let userProfiles = Dictionary(uniqueKeysWithValues: mockData.users.map { ($0.id, $0) })
    
    return VStack(spacing: 16) {
        // Pinned post
        NoticeboardCardView(
            post: mockPosts[0],
            userProfiles: userProfiles,
            canEdit: true,
            onEdit: { _ in },
            onDelete: { }
        )
        
        // Regular post
        NoticeboardCardView(
            post: mockPosts[1],
            userProfiles: userProfiles,
            canEdit: false,
            onEdit: { _ in },
            onDelete: { }
        )
    }
    .padding()
}