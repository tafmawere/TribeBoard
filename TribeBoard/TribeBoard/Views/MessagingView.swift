import SwiftUI

/// Main messaging view that displays family conversations and noticeboard posts
struct MessagingView: View {
    @StateObject private var viewModel: MessagingViewModel
    @EnvironmentObject var appState: AppState
    
    @State private var selectedTab: MessagingTab = .messages
    @State private var showingComposer = false
    @State private var showingNoticeboardComposer = false
    
    enum MessagingTab: String, CaseIterable {
        case messages = "Messages"
        case noticeboard = "Noticeboard"
        
        var icon: String {
            switch self {
            case .messages:
                return "message"
            case .noticeboard:
                return "pin"
            }
        }
    }
    
    // MARK: - Initialization
    
    init(currentUserId: UUID, currentUserRole: Role) {
        self._viewModel = StateObject(wrappedValue: MessagingViewModel(
            currentUserId: currentUserId,
            currentUserRole: currentUserRole
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab selector
                    tabSelectorView
                    
                    // Content based on selected tab
                    switch selectedTab {
                    case .messages:
                        messagesContentView
                    case .noticeboard:
                        noticeboardContentView
                    }
                }
            }
            .navigationTitle("Family Communication")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        switch selectedTab {
                        case .messages:
                            showingComposer = true
                        case .noticeboard:
                            showingNoticeboardComposer = true
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.brandPrimary)
                    }
                }
            }
        }
        .task {
            await viewModel.loadMessages()
        }
        .refreshable {
            await viewModel.refreshMessages()
        }
        .withToast()
        .sheet(isPresented: $showingComposer) {
            MessageComposerView(
                onSend: { content, type in
                    await viewModel.sendMessage(content: content, type: type)
                    showingComposer = false
                }
            )
        }
        .sheet(isPresented: $showingNoticeboardComposer) {
            NoticeboardComposerView(
                onPost: { title, content in
                    await viewModel.postToNoticeboard(title: title, content: content)
                    showingNoticeboardComposer = false
                }
            )
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var tabSelectorView: some View {
        HStack(spacing: 0) {
            ForEach(MessagingTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.subheadline)
                            
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedTab == tab ? .brandPrimary : .secondary)
                        
                        // Unread indicator
                        if tab == .messages && viewModel.unreadMessagesCount > 0 {
                            Text("\(viewModel.unreadMessagesCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.red)
                                .cornerRadius(8)
                        } else if tab == .noticeboard && viewModel.unreadNoticeboardCount > 0 {
                            Text("\(viewModel.unreadNoticeboardCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab ? 
                        Color.brandPrimary.opacity(0.1) : 
                        Color.clear
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var messagesContentView: some View {
        Group {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                LoadingStateView(
                    message: "Loading messages...",
                    style: .card
                )
                .padding()
            } else if viewModel.messages.isEmpty {
                EmptyStateView(
                    icon: "message",
                    title: "No Messages Yet",
                    message: "Start a conversation with your family",
                    actionTitle: "Send First Message",
                    action: {
                        showingComposer = true
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages, id: \.id) { message in
                            MessageBubbleView(
                                message: message,
                                userProfiles: viewModel.userProfiles,
                                isCurrentUser: message.sender == viewModel.currentUserId,
                                onMarkAsRead: {
                                    await viewModel.markMessageAsRead(message)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var noticeboardContentView: some View {
        Group {
            if viewModel.isLoading && viewModel.noticeboardPosts.isEmpty {
                LoadingStateView(
                    message: "Loading noticeboard...",
                    style: .card
                )
                .padding()
            } else if viewModel.noticeboardPosts.isEmpty {
                EmptyStateView(
                    icon: "pin",
                    title: "No Posts Yet",
                    message: "Share announcements and updates with your family",
                    actionTitle: "Create First Post",
                    action: {
                        showingNoticeboardComposer = true
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.noticeboardPosts, id: \.id) { post in
                            NoticeboardCardView(
                                post: post,
                                userProfiles: viewModel.userProfiles,
                                canEdit: post.authorId == viewModel.currentUserId || viewModel.canModerate,
                                onEdit: { updatedPost in
                                    await viewModel.updateNoticeboardPost(updatedPost)
                                },
                                onDelete: {
                                    await viewModel.deleteNoticeboardPost(post)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let mockData = MockDataGenerator.mockMawereFamily()
    let mockUserId = mockData.users[0].id
    
    MessagingView(
        currentUserId: mockUserId,
        currentUserRole: .parentAdmin
    )
    .environmentObject(AppState())
}