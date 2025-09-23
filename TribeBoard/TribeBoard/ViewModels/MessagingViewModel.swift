import SwiftUI
import Foundation

/// ViewModel for messaging functionality with mock data and instant responses
@MainActor
class MessagingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// List of family messages
    @Published var messages: [FamilyMessage] = []
    
    /// List of noticeboard posts
    @Published var noticeboardPosts: [NoticeboardPost] = []
    
    /// Associated user profiles for message senders
    @Published var userProfiles: [UUID: UserProfile] = [:]
    
    /// Loading state for async operations
    @Published var isLoading = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Success message for operations
    @Published var successMessage: String?
    
    /// Count of unread messages
    @Published var unreadMessagesCount: Int = 0
    
    /// Count of unread noticeboard posts
    @Published var unreadNoticeboardCount: Int = 0
    
    // MARK: - Dependencies
    
    let currentUserId: UUID
    let currentUserRole: Role
    
    // MARK: - Computed Properties
    
    /// Check if current user can moderate content
    var canModerate: Bool {
        currentUserRole == .parentAdmin || currentUserRole == .adult
    }
    
    /// Check if current user can send messages
    var canSendMessages: Bool {
        switch currentUserRole {
        case .parentAdmin, .adult:
            return true
        case .kid:
            // Kids can send messages if family settings allow
            return true // For prototype, allow all roles
        case .visitor:
            return false // Visitors cannot send messages
        }
    }
    
    // MARK: - Initialization
    
    init(currentUserId: UUID, currentUserRole: Role) {
        self.currentUserId = currentUserId
        self.currentUserRole = currentUserRole
        
        // Load mock data immediately
        loadMockData()
    }
    
    // MARK: - Public Methods
    
    /// Load messages and noticeboard posts with mock responses
    func loadMessages() async {
        isLoading = true
        errorMessage = nil
        
        // Simulate brief loading for realism
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        loadMockData()
        updateUnreadCounts()
        
        isLoading = false
    }
    
    /// Refresh messages and noticeboard posts
    func refreshMessages() async {
        // Simulate refresh time
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        loadMockData()
        updateUnreadCounts()
        
        successMessage = "Messages refreshed"
    }
    
    /// Send a new message with mock validation and instant response
    func sendMessage(content: String, type: FamilyMessage.MessageType) async {
        guard canSendMessages else {
            errorMessage = "You don't have permission to send messages"
            return
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Message cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Simulate sending time
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        // Create new message
        let newMessage = FamilyMessage(
            id: UUID(),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            sender: currentUserId,
            timestamp: Date(),
            type: type,
            isRead: true, // Mark as read for sender
            attachmentUrl: nil
        )
        
        // Add to messages list
        messages.append(newMessage)
        messages.sort { $0.timestamp > $1.timestamp }
        
        successMessage = "Message sent successfully"
        isLoading = false
    }
    
    /// Post to noticeboard with mock validation
    func postToNoticeboard(title: String, content: String) async {
        guard canModerate else {
            errorMessage = "You don't have permission to post to the noticeboard"
            return
        }
        
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Post title cannot be empty"
            return
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Post content cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Simulate posting time
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Create new noticeboard post
        let newPost = NoticeboardPost(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            authorId: currentUserId,
            timestamp: Date(),
            isPinned: false,
            isRead: true, // Mark as read for author
            attachmentUrl: nil
        )
        
        // Add to noticeboard posts
        noticeboardPosts.insert(newPost, at: 0) // Add at beginning
        
        successMessage = "Post created successfully"
        isLoading = false
    }
    
    /// Mark a message as read
    func markMessageAsRead(_ message: FamilyMessage) async {
        guard !message.isRead else { return }
        
        // Find and update the message
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = FamilyMessage(
                id: message.id,
                content: message.content,
                sender: message.sender,
                timestamp: message.timestamp,
                type: message.type,
                isRead: true,
                attachmentUrl: message.attachmentUrl
            )
            
            updateUnreadCounts()
        }
    }
    
    /// Update a noticeboard post
    func updateNoticeboardPost(_ updatedPost: NoticeboardPost) async {
        guard updatedPost.authorId == currentUserId || canModerate else {
            errorMessage = "You don't have permission to edit this post"
            return
        }
        
        isLoading = true
        
        // Simulate update time
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        if let index = noticeboardPosts.firstIndex(where: { $0.id == updatedPost.id }) {
            noticeboardPosts[index] = updatedPost
            successMessage = "Post updated successfully"
        }
        
        isLoading = false
    }
    
    /// Delete a noticeboard post
    func deleteNoticeboardPost(_ post: NoticeboardPost) async {
        guard post.authorId == currentUserId || canModerate else {
            errorMessage = "You don't have permission to delete this post"
            return
        }
        
        isLoading = true
        
        // Simulate deletion time
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        noticeboardPosts.removeAll { $0.id == post.id }
        successMessage = "Post deleted successfully"
        
        isLoading = false
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Clear success message
    func clearSuccess() {
        successMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// Load mock data for messages and noticeboard
    private func loadMockData() {
        let mockData = MockDataGenerator.mockMawereFamily()
        
        // Set user profiles
        userProfiles = Dictionary(uniqueKeysWithValues: mockData.users.map { ($0.id, $0) })
        
        // Load mock messages
        messages = MockDataGenerator.mockFamilyMessages()
            .sorted { $0.timestamp > $1.timestamp }
        
        // Load mock noticeboard posts
        noticeboardPosts = MockDataGenerator.mockNoticeboardPosts()
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Update unread message and post counts
    private func updateUnreadCounts() {
        unreadMessagesCount = messages.filter { !$0.isRead && $0.sender != currentUserId }.count
        unreadNoticeboardCount = noticeboardPosts.filter { !$0.isRead && $0.authorId != currentUserId }.count
    }
}