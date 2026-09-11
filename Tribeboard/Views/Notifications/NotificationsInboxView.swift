import SwiftUI

struct NotificationsInboxView: View {
    @State private var selectedFilter: NotificationsFilter = .all
    @State private var notifications: [NotificationInboxItem]

    init(notifications: [NotificationInboxItem] = NotificationInboxBootstrap.liveItems) {
        _notifications = State(initialValue: notifications)
    }

    private var filteredItems: [NotificationInboxItem] {
        switch selectedFilter {
        case .all:
            return notifications
        case .unread:
            return notifications.filter(\.isUnread)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(NotificationsFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 2)

                if filteredItems.isEmpty {
                    NotificationStitchCard {
                        VStack(spacing: 10) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(NotificationTheme.textSecondary)
                            Text(selectedFilter == .unread ? "No unread notifications" : "No notifications")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(NotificationTheme.textPrimary)
                            Text(selectedFilter == .unread
                                 ? "You are all caught up for now."
                                 : "New run and household updates will appear here.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(NotificationTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                } else {
                    ForEach(filteredItems) { item in
                        NotificationInboxCard(item: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(item.isUnread ? "Read" : "Unread") {
                                    toggleReadState(for: item.id)
                                }
                                .tint(NotificationTheme.primary)
                            }
                    }
                }
            }
            .padding(16)
        }
        .background(NotificationTheme.background.ignoresSafeArea())
        .navigationTitle("Notifications")
    }

    private func toggleReadState(for id: NotificationInboxItem.ID) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].isUnread.toggle()
    }
}

#Preview {
    NavigationStack {
        NotificationsInboxView(notifications: NotificationMockData.inboxItems)
    }
}
