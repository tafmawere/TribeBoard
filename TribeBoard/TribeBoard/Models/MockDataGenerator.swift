import Foundation
import SwiftData

// MARK: - Prototype Data Models

/// Calendar event for prototype
struct CalendarEvent {
    let id: UUID
    let title: String
    let date: Date
    let type: EventType
    let participants: [UUID]
    let description: String?
    let location: String?
    
    enum EventType: String, CaseIterable {
        case birthday = "birthday"
        case appointment = "appointment"
        case schoolEvent = "school_event"
        case familyActivity = "family_activity"
        case reminder = "reminder"
        
        var displayName: String {
            switch self {
            case .birthday: return "Birthday"
            case .appointment: return "Appointment"
            case .schoolEvent: return "School Event"
            case .familyActivity: return "Family Activity"
            case .reminder: return "Reminder"
            }
        }
        
        var icon: String {
            switch self {
            case .birthday: return "🎂"
            case .appointment: return "📅"
            case .schoolEvent: return "🏫"
            case .familyActivity: return "👨‍👩‍👧‍👦"
            case .reminder: return "⏰"
            }
        }
    }
}

/// Family task for prototype
struct FamilyTask {
    let id: UUID
    let title: String
    let description: String?
    let assignedTo: UUID
    let assignedBy: UUID
    let dueDate: Date?
    let status: TaskStatus
    let points: Int
    let category: TaskCategory
    let createdAt: Date
    
    enum TaskStatus: String, CaseIterable {
        case pending = "pending"
        case inProgress = "in_progress"
        case completed = "completed"
        case overdue = "overdue"
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .overdue: return "Overdue"
            }
        }
        
        var color: String {
            switch self {
            case .pending: return "gray"
            case .inProgress: return "blue"
            case .completed: return "green"
            case .overdue: return "red"
            }
        }
    }
    
    enum TaskCategory: String, CaseIterable {
        case chores = "chores"
        case homework = "homework"
        case personal = "personal"
        case family = "family"
        
        var displayName: String {
            switch self {
            case .chores: return "Chores"
            case .homework: return "Homework"
            case .personal: return "Personal"
            case .family: return "Family"
            }
        }
        
        var icon: String {
            switch self {
            case .chores: return "🧹"
            case .homework: return "📚"
            case .personal: return "👤"
            case .family: return "👨‍👩‍👧‍👦"
            }
        }
    }
}

/// Family message for prototype
struct FamilyMessage {
    let id: UUID
    let content: String
    let sender: UUID
    let timestamp: Date
    let type: MessageType
    let isRead: Bool
    let attachmentUrl: URL?
    
    enum MessageType: String, CaseIterable {
        case text = "text"
        case announcement = "announcement"
        case photo = "photo"
        case reminder = "reminder"
        
        var displayName: String {
            switch self {
            case .text: return "Message"
            case .announcement: return "Announcement"
            case .photo: return "Photo"
            case .reminder: return "Reminder"
            }
        }
    }
}

/// Noticeboard post for prototype
struct NoticeboardPost {
    let id: UUID
    let title: String
    let content: String
    let authorId: UUID
    let timestamp: Date
    let isPinned: Bool
    let isRead: Bool
    let attachmentUrl: URL?
    
    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        authorId: UUID,
        timestamp: Date = Date(),
        isPinned: Bool = false,
        isRead: Bool = false,
        attachmentUrl: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.authorId = authorId
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.isRead = isRead
        self.attachmentUrl = attachmentUrl
    }
}

/// School run data for prototype
struct SchoolRun {
    let id: UUID
    let route: String
    let pickupTime: Date
    let dropoffTime: Date
    let driver: UUID
    let passengers: [UUID]
    let status: RunStatus
    let notes: String?
    
    enum RunStatus: String, CaseIterable {
        case scheduled = "scheduled"
        case inProgress = "in_progress"
        case completed = "completed"
        case cancelled = "cancelled"
        
        var displayName: String {
            switch self {
            case .scheduled: return "Scheduled"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .cancelled: return "Cancelled"
            }
        }
        
        var color: String {
            switch self {
            case .scheduled: return "blue"
            case .inProgress: return "orange"
            case .completed: return "green"
            case .cancelled: return "red"
            }
        }
    }
}

/// Family settings for prototype
struct FamilySettings {
    let familyId: UUID
    let notificationsEnabled: Bool
    let quietHoursStart: Date
    let quietHoursEnd: Date
    let allowChildMessaging: Bool
    let requireTaskApproval: Bool
    let pointsSystemEnabled: Bool
    let maxPointsPerTask: Int
}

/// Mock notification for school run events
struct SchoolRunNotification {
    let id: UUID
    let title: String
    let message: String
    let timestamp: Date
    let type: NotificationType
    let schoolRunId: UUID
    
    enum NotificationType {
        case started
        case arriving
        case completed
        case delayed
    }
}

/// Mock error scenarios for prototype
struct MockError {
    let type: ErrorType
    let title: String
    let message: String
    let recoveryAction: String?
    
    enum ErrorType: String, CaseIterable {
        case network = "network"
        case authentication = "authentication"
        case validation = "validation"
        case permission = "permission"
        case notFound = "not_found"
        case serverError = "server_error"
        
        var displayName: String {
            switch self {
            case .network: return "Network Error"
            case .authentication: return "Authentication Error"
            case .validation: return "Validation Error"
            case .permission: return "Permission Error"
            case .notFound: return "Not Found"
            case .serverError: return "Server Error"
            }
        }
    }
}

/// User journey scenarios for prototype
enum UserJourneyScenario: String, CaseIterable {
    case newUser = "new_user"
    case existingUser = "existing_user"
    case familyAdmin = "family_admin"
    case childUser = "child_user"
    case visitorUser = "visitor_user"
    
    var displayName: String {
        switch self {
        case .newUser: return "New User"
        case .existingUser: return "Existing User"
        case .familyAdmin: return "Family Admin"
        case .childUser: return "Child User"
        case .visitorUser: return "Visitor User"
        }
    }
}

/// Provides mock data for testing UI components and prototyping
struct MockDataGenerator {
    
    // MARK: - Family Mock Data
    
    /// Generates the default Mawere Family with comprehensive member data
    static func mockMawereFamily() -> (family: Family, users: [UserProfile], memberships: [Membership]) {
        let users = [
            UserProfile(displayName: "Tafadzwa Mawere", appleUserIdHash: "hash_tafadzwa"),
            UserProfile(displayName: "Grace Mawere", appleUserIdHash: "hash_grace"),
            UserProfile(displayName: "Ethan Mawere", appleUserIdHash: "hash_ethan"),
            UserProfile(displayName: "Zoe Mawere", appleUserIdHash: "hash_zoe"),
            UserProfile(displayName: "Grandma Rose", appleUserIdHash: "hash_rose")
        ]
        
        let family = Family(name: "Mawere Family", code: "MAW2024", createdByUserId: users[0].id)
        
        let memberships = [
            Membership(family: family, user: users[0], role: .parentAdmin),
            Membership(family: family, user: users[1], role: .adult),
            Membership(family: family, user: users[2], role: .kid),
            Membership(family: family, user: users[3], role: .kid),
            Membership(family: family, user: users[4], role: .visitor)
        ]
        
        return (family, users, memberships)
    }
    
    /// Generates a complete family with members for testing (legacy method)
    static func mockFamilyWithMembers() -> (family: Family, users: [UserProfile], memberships: [Membership]) {
        return mockMawereFamily()
    }
    
    /// Generates multiple families for testing family selection
    static func mockMultipleFamilies() -> [(family: Family, memberCount: Int)] {
        let creatorId = UUID()
        return [
            (Family(name: "Mawere Family", code: "MAW2024", createdByUserId: creatorId), 5),
            (Family(name: "The Smith Family", code: "SMI123", createdByUserId: creatorId), 4),
            (Family(name: "The Garcia Family", code: "GAR456", createdByUserId: creatorId), 3),
            (Family(name: "The Chen Family", code: "CHE789", createdByUserId: creatorId), 5),
            (Family(name: "The Wilson Family", code: "WIL012", createdByUserId: creatorId), 2)
        ]
    }
    
    // MARK: - User Journey Scenarios
    
    /// Generates mock data for specific user journey scenarios
    static func mockDataForScenario(_ scenario: UserJourneyScenario) -> (family: Family, users: [UserProfile], memberships: [Membership], currentUser: UserProfile) {
        let (family, users, memberships) = mockMawereFamily()
        
        switch scenario {
        case .newUser:
            // New user with no family yet
            let newUser = UserProfile(displayName: "New User", appleUserIdHash: "hash_new_user")
            return (family, users + [newUser], memberships, newUser)
            
        case .existingUser:
            // Existing user who is an adult member
            return (family, users, memberships, users[1]) // Grace Mawere
            
        case .familyAdmin:
            // Family admin with full permissions
            return (family, users, memberships, users[0]) // Tafadzwa Mawere
            
        case .childUser:
            // Child user with limited permissions
            return (family, users, memberships, users[2]) // Ethan Mawere
            
        case .visitorUser:
            // Visitor with restricted access
            return (family, users, memberships, users[4]) // Grandma Rose
        }
    }
    
    // MARK: - Role Testing Data
    
    /// Provides all available roles for testing role selection UI
    static var allRoles: [Role] {
        return Role.allCases
    }
    
    /// Provides role constraints scenarios for testing
    static func roleConstraintScenarios() -> [(scenario: String, availableRoles: [Role])] {
        return [
            ("No Parent Admin exists", Role.allCases),
            ("Parent Admin already exists", [.adult, .kid, .visitor]),
            ("Full family", [.visitor]) // Only visitor slots available
        ]
    }
    
    // MARK: - Membership Status Testing
    
    /// Provides different membership status scenarios
    static func membershipStatusScenarios() -> [Membership] {
        let family = Family(name: "Test Family", code: "TEST01", createdByUserId: UUID())
        let users = [
            UserProfile(displayName: "User 1", appleUserIdHash: "hash1"),
            UserProfile(displayName: "User 2", appleUserIdHash: "hash2"),
            UserProfile(displayName: "User 3", appleUserIdHash: "hash3"),
            UserProfile(displayName: "User 4", appleUserIdHash: "hash4"),
            UserProfile(displayName: "User 5", appleUserIdHash: "hash5")
        ]
        
        let memberships = [
            Membership(family: family, user: users[0], role: .parentAdmin),
            Membership(family: family, user: users[1], role: .adult),
            Membership(family: family, user: users[2], role: .kid),
            Membership(family: family, user: users[3], role: .adult),
            Membership(family: family, user: users[4], role: .visitor)
        ]
        
        // Set different statuses
        memberships[3].status = .invited
        memberships[4].status = .removed
        
        return memberships
    }
    
    // MARK: - Authentication Testing
    
    /// Provides mock authenticated user for testing
    static func mockAuthenticatedUser() -> UserProfile {
        return UserProfile(
            displayName: "Current User",
            appleUserIdHash: "current_user_hash"
        )
    }
    
    // MARK: - Family Code Testing
    
    /// Provides various family code formats for testing validation
    static var testFamilyCodes: [String] {
        return [
            "ABC123",    // Valid 6-character
            "DEMO01",    // Valid 6-character with numbers
            "FAMILY8",   // Valid 7-character
            "TESTCODE",  // Valid 8-character
            "AB12",      // Invalid - too short
            "TOOLONGCODE", // Invalid - too long
            "abc123",    // Valid but lowercase
            "123ABC"     // Valid numbers first
        ]
    }
    
    // MARK: - Calendar Events Mock Data
    
    /// Generates mock calendar events for the Mawere Family
    static func mockCalendarEvents() -> [CalendarEvent] {
        let (_, users, _) = mockMawereFamily()
        let calendar = Calendar.current
        let today = Date()
        
        return [
            CalendarEvent(
                id: UUID(),
                title: "Ethan's Birthday Party",
                date: calendar.date(byAdding: .day, value: 3, to: today)!,
                type: .birthday,
                participants: [users[2].id, users[0].id, users[1].id],
                description: "Ethan turns 12! Pizza party at home.",
                location: "Home"
            ),
            CalendarEvent(
                id: UUID(),
                title: "Parent-Teacher Conference",
                date: calendar.date(byAdding: .day, value: 7, to: today)!,
                type: .schoolEvent,
                participants: [users[0].id, users[1].id],
                description: "Meeting with Mrs. Johnson about Zoe's progress",
                location: "Greenwood Elementary"
            ),
            CalendarEvent(
                id: UUID(),
                title: "Family Movie Night",
                date: calendar.date(byAdding: .day, value: 1, to: today)!,
                type: .familyActivity,
                participants: users.map { $0.id },
                description: "Weekly family movie night - Zoe's turn to pick!",
                location: "Living Room"
            ),
            CalendarEvent(
                id: UUID(),
                title: "Dentist Appointment - Zoe",
                date: calendar.date(byAdding: .day, value: 5, to: today)!,
                type: .appointment,
                participants: [users[3].id, users[1].id],
                description: "Regular checkup and cleaning",
                location: "Smile Dental Clinic"
            ),
            CalendarEvent(
                id: UUID(),
                title: "School Science Fair",
                date: calendar.date(byAdding: .day, value: 14, to: today)!,
                type: .schoolEvent,
                participants: [users[2].id],
                description: "Ethan presenting his volcano project",
                location: "School Gymnasium"
            ),
            CalendarEvent(
                id: UUID(),
                title: "Grace's Work Presentation",
                date: calendar.date(byAdding: .day, value: 2, to: today)!,
                type: .reminder,
                participants: [users[1].id],
                description: "Important client presentation - wish me luck!",
                location: "Downtown Office"
            )
        ]
    }
    
    // MARK: - Family Tasks Mock Data
    
    /// Generates mock family tasks for the Mawere Family
    static func mockFamilyTasks() -> [FamilyTask] {
        let (_, users, _) = mockMawereFamily()
        let calendar = Calendar.current
        let today = Date()
        
        return [
            FamilyTask(
                id: UUID(),
                title: "Clean bedroom",
                description: "Tidy up room and make bed",
                assignedTo: users[2].id, // Ethan
                assignedBy: users[0].id, // Tafadzwa
                dueDate: calendar.date(byAdding: .day, value: 1, to: today),
                status: .pending,
                points: 10,
                category: .chores,
                createdAt: calendar.date(byAdding: .day, value: -1, to: today)!
            ),
            FamilyTask(
                id: UUID(),
                title: "Math homework",
                description: "Complete chapter 5 exercises",
                assignedTo: users[3].id, // Zoe
                assignedBy: users[1].id, // Grace
                dueDate: calendar.date(byAdding: .day, value: 0, to: today),
                status: .inProgress,
                points: 15,
                category: .homework,
                createdAt: calendar.date(byAdding: .day, value: -2, to: today)!
            ),
            FamilyTask(
                id: UUID(),
                title: "Take out trash",
                description: "Empty all bins and take to curb",
                assignedTo: users[2].id, // Ethan
                assignedBy: users[0].id, // Tafadzwa
                dueDate: calendar.date(byAdding: .day, value: -1, to: today),
                status: .overdue,
                points: 5,
                category: .chores,
                createdAt: calendar.date(byAdding: .day, value: -3, to: today)!
            ),
            FamilyTask(
                id: UUID(),
                title: "Load dishwasher",
                description: "Load and start the dishwasher after dinner",
                assignedTo: users[3].id, // Zoe
                assignedBy: users[1].id, // Grace
                dueDate: nil,
                status: .completed,
                points: 8,
                category: .chores,
                createdAt: calendar.date(byAdding: .day, value: -1, to: today)!
            ),
            FamilyTask(
                id: UUID(),
                title: "Practice piano",
                description: "30 minutes of piano practice",
                assignedTo: users[3].id, // Zoe
                assignedBy: users[1].id, // Grace
                dueDate: calendar.date(byAdding: .day, value: 0, to: today),
                status: .pending,
                points: 12,
                category: .personal,
                createdAt: today
            ),
            FamilyTask(
                id: UUID(),
                title: "Plan weekend trip",
                description: "Research and book family weekend getaway",
                assignedTo: users[0].id, // Tafadzwa
                assignedBy: users[1].id, // Grace
                dueDate: calendar.date(byAdding: .day, value: 7, to: today),
                status: .inProgress,
                points: 20,
                category: .family,
                createdAt: calendar.date(byAdding: .day, value: -1, to: today)!
            )
        ]
    }
    
    // MARK: - Family Messages Mock Data
    
    /// Generates mock family messages for the Mawere Family
    static func mockFamilyMessages() -> [FamilyMessage] {
        let (_, users, _) = mockMawereFamily()
        let calendar = Calendar.current
        let now = Date()
        
        return [
            FamilyMessage(
                id: UUID(),
                content: "Don't forget we have movie night tonight! 🍿",
                sender: users[1].id, // Grace
                timestamp: calendar.date(byAdding: .hour, value: -2, to: now)!,
                type: .announcement,
                isRead: true,
                attachmentUrl: nil
            ),
            FamilyMessage(
                id: UUID(),
                content: "I finished my math homework! Can I have extra screen time? 😊",
                sender: users[3].id, // Zoe
                timestamp: calendar.date(byAdding: .hour, value: -1, to: now)!,
                type: .text,
                isRead: false,
                attachmentUrl: nil
            ),
            FamilyMessage(
                id: UUID(),
                content: "Great job on cleaning your room, Ethan! 10 points earned! ⭐",
                sender: users[0].id, // Tafadzwa
                timestamp: calendar.date(byAdding: .minute, value: -30, to: now)!,
                type: .text,
                isRead: true,
                attachmentUrl: nil
            ),
            FamilyMessage(
                id: UUID(),
                content: "Reminder: Parent-teacher conference is next Tuesday at 3 PM",
                sender: users[1].id, // Grace
                timestamp: calendar.date(byAdding: .day, value: -1, to: now)!,
                type: .reminder,
                isRead: true,
                attachmentUrl: nil
            ),
            FamilyMessage(
                id: UUID(),
                content: "Look what I made in art class today!",
                sender: users[2].id, // Ethan
                timestamp: calendar.date(byAdding: .hour, value: -4, to: now)!,
                type: .photo,
                isRead: true,
                attachmentUrl: URL(string: "https://example.com/ethan-artwork.jpg")
            ),
            FamilyMessage(
                id: UUID(),
                content: "Weekly chore assignments are now posted on the board! 📋",
                sender: users[0].id, // Tafadzwa
                timestamp: calendar.date(byAdding: .day, value: -2, to: now)!,
                type: .announcement,
                isRead: true,
                attachmentUrl: nil
            )
        ]
    }
    
    // MARK: - Noticeboard Posts Mock Data
    
    /// Generates mock noticeboard posts for the Mawere Family
    static func mockNoticeboardPosts() -> [NoticeboardPost] {
        let (_, users, _) = mockMawereFamily()
        let calendar = Calendar.current
        let now = Date()
        
        return [
            NoticeboardPost(
                id: UUID(),
                title: "Family Movie Night This Friday! 🎬",
                content: "Don't forget about our weekly family movie night this Friday at 7 PM. It's Zoe's turn to pick the movie! We'll have popcorn and hot chocolate ready. Looking forward to spending time together as a family.",
                authorId: users[1].id, // Grace
                timestamp: calendar.date(byAdding: .hour, value: -6, to: now)!,
                isPinned: true,
                isRead: true,
                attachmentUrl: nil
            ),
            NoticeboardPost(
                id: UUID(),
                title: "New Chore Schedule Posted",
                content: "I've updated the weekly chore schedule on the refrigerator. Everyone has age-appropriate tasks, and remember that completing chores earns points toward weekend privileges. Let's work together to keep our home tidy!",
                authorId: users[0].id, // Tafadzwa
                timestamp: calendar.date(byAdding: .day, value: -1, to: now)!,
                isPinned: false,
                isRead: false,
                attachmentUrl: nil
            ),
            NoticeboardPost(
                id: UUID(),
                title: "Parent-Teacher Conferences Next Week",
                content: "Reminder that parent-teacher conferences are scheduled for next Tuesday and Wednesday. I've already booked our slots:\n\n• Ethan: Tuesday 3:00 PM\n• Zoe: Wednesday 2:30 PM\n\nBoth kids have been doing great this semester!",
                authorId: users[1].id, // Grace
                timestamp: calendar.date(byAdding: .day, value: -2, to: now)!,
                isPinned: false,
                isRead: true,
                attachmentUrl: nil
            ),
            NoticeboardPost(
                id: UUID(),
                title: "Weekend Trip Planning",
                content: "I'm researching options for our family weekend getaway next month. So far I'm looking at:\n\n1. Beach house rental in Santa Monica\n2. Cabin in Big Bear\n3. Camping at Joshua Tree\n\nWhat does everyone think? Let me know your preferences!",
                authorId: users[0].id, // Tafadzwa
                timestamp: calendar.date(byAdding: .day, value: -3, to: now)!,
                isPinned: false,
                isRead: true,
                attachmentUrl: nil
            ),
            NoticeboardPost(
                id: UUID(),
                title: "Grandma Rose's Visit",
                content: "Grandma Rose will be visiting us next weekend! She's excited to see everyone and catch up. I'll be preparing her favorite meals, and she mentioned she has some special gifts for the kids. Let's make sure the guest room is ready.",
                authorId: users[1].id, // Grace
                timestamp: calendar.date(byAdding: .day, value: -5, to: now)!,
                isPinned: false,
                isRead: true,
                attachmentUrl: nil
            ),
            NoticeboardPost(
                id: UUID(),
                title: "Screen Time Guidelines Update",
                content: "After our family discussion, we've updated our screen time guidelines:\n\n• Weekdays: 1 hour after homework\n• Weekends: 2 hours per day\n• No screens during meals\n• All devices charge outside bedrooms overnight\n\nThese rules help us balance technology with family time.",
                authorId: users[0].id, // Tafadzwa
                timestamp: calendar.date(byAdding: .weekOfYear, value: -1, to: now)!,
                isPinned: true,
                isRead: true,
                attachmentUrl: nil
            )
        ]
    }
    
    // MARK: - School Run Mock Data
    
    /// Generates mock school run data for the Mawere Family
    static func mockSchoolRuns() -> [SchoolRun] {
        let (_, users, _) = mockMawereFamily()
        let calendar = Calendar.current
        let today = Date()
        
        // Create times for school runs
        let morningPickup = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: today)!
        let morningDropoff = calendar.date(bySettingHour: 8, minute: 15, second: 0, of: today)!
        let afternoonPickup = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: today)!
        let afternoonDropoff = calendar.date(bySettingHour: 15, minute: 45, second: 0, of: today)!
        
        return [
            SchoolRun(
                id: UUID(),
                route: "Home → Greenwood Elementary",
                pickupTime: morningPickup,
                dropoffTime: morningDropoff,
                driver: users[0].id, // Tafadzwa
                passengers: [users[2].id, users[3].id], // Ethan and Zoe
                status: .completed,
                notes: "Both kids dropped off safely"
            ),
            SchoolRun(
                id: UUID(),
                route: "Greenwood Elementary → Home",
                pickupTime: afternoonPickup,
                dropoffTime: afternoonDropoff,
                driver: users[1].id, // Grace
                passengers: [users[2].id, users[3].id], // Ethan and Zoe
                status: .scheduled,
                notes: "Pick up from main entrance"
            ),
            SchoolRun(
                id: UUID(),
                route: "Home → Soccer Practice",
                pickupTime: calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: today)!)!,
                dropoffTime: calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 16, minute: 20, second: 0, of: today)!)!,
                driver: users[0].id, // Tafadzwa
                passengers: [users[2].id], // Ethan
                status: .scheduled,
                notes: "Soccer practice at community center"
            )
        ]
    }
    
    /// Generates extended school run data with various scenarios for comprehensive testing
    static func mockExtendedSchoolRuns() -> [SchoolRun] {
        let (_, users, _) = mockMawereFamily()
        let calendar = Calendar.current
        let today = Date()
        
        var schoolRuns: [SchoolRun] = []
        
        // Today's runs
        schoolRuns.append(contentsOf: [
            SchoolRun(
                id: UUID(),
                route: "Home → Greenwood Elementary",
                pickupTime: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: today)!,
                dropoffTime: calendar.date(bySettingHour: 8, minute: 15, second: 0, of: today)!,
                driver: users[0].id, // Tafadzwa
                passengers: [users[2].id, users[3].id], // Ethan and Zoe
                status: .completed,
                notes: "Both kids dropped off safely"
            ),
            SchoolRun(
                id: UUID(),
                route: "Greenwood Elementary → Home",
                pickupTime: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: today)!,
                dropoffTime: calendar.date(bySettingHour: 15, minute: 45, second: 0, of: today)!,
                driver: users[1].id, // Grace
                passengers: [users[2].id, users[3].id], // Ethan and Zoe
                status: .scheduled,
                notes: "Pick up from main entrance"
            ),
            SchoolRun(
                id: UUID(),
                route: "Home → Piano Lessons",
                pickupTime: calendar.date(bySettingHour: 16, minute: 30, second: 0, of: today)!,
                dropoffTime: calendar.date(bySettingHour: 16, minute: 45, second: 0, of: today)!,
                driver: users[1].id, // Grace
                passengers: [users[3].id], // Zoe
                status: .scheduled,
                notes: "Weekly piano lesson at music center"
            )
        ])
        
        // Tomorrow's runs
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        schoolRuns.append(contentsOf: [
            SchoolRun(
                id: UUID(),
                route: "Home → Greenwood Elementary",
                pickupTime: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: tomorrow)!,
                dropoffTime: calendar.date(bySettingHour: 8, minute: 15, second: 0, of: tomorrow)!,
                driver: users[1].id, // Grace
                passengers: [users[2].id, users[3].id], // Ethan and Zoe
                status: .scheduled,
                notes: "Tomorrow's morning drop-off"
            ),
            SchoolRun(
                id: UUID(),
                route: "Greenwood Elementary → Soccer Practice",
                pickupTime: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: tomorrow)!,
                dropoffTime: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: tomorrow)!,
                driver: users[0].id, // Tafadzwa
                passengers: [users[2].id], // Ethan
                status: .scheduled,
                notes: "Direct to soccer practice after school"
            ),
            SchoolRun(
                id: UUID(),
                route: "Soccer Practice → Home",
                pickupTime: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: tomorrow)!,
                dropoffTime: calendar.date(bySettingHour: 17, minute: 20, second: 0, of: tomorrow)!,
                driver: users[0].id, // Tafadzwa
                passengers: [users[2].id], // Ethan
                status: .scheduled,
                notes: "Pick up after soccer practice"
            )
        ])
        
        // Day after tomorrow's runs
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today)!
        schoolRuns.append(contentsOf: [
            SchoolRun(
                id: UUID(),
                route: "Home → Greenwood Elementary",
                pickupTime: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: dayAfterTomorrow)!,
                dropoffTime: calendar.date(bySettingHour: 8, minute: 15, second: 0, of: dayAfterTomorrow)!,
                driver: users[0].id, // Tafadzwa
                passengers: [users[2].id, users[3].id], // Ethan and Zoe
                status: .scheduled,
                notes: "Regular morning drop-off"
            ),
            SchoolRun(
                id: UUID(),
                route: "Greenwood Elementary → Dentist",
                pickupTime: calendar.date(bySettingHour: 14, minute: 30, second: 0, of: dayAfterTomorrow)!,
                dropoffTime: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: dayAfterTomorrow)!,
                driver: users[1].id, // Grace
                passengers: [users[3].id], // Zoe
                status: .scheduled,
                notes: "Early pickup for dentist appointment"
            )
        ])
        
        return schoolRuns
    }
    
    /// Generates mock GPS tracking notifications for school runs
    static func mockSchoolRunNotifications() -> [SchoolRunNotification] {
        let schoolRuns = mockSchoolRuns()
        let now = Date()
        let calendar = Calendar.current
        
        return [
            SchoolRunNotification(
                id: UUID(),
                title: "School Run Started",
                message: "Navigation started for Home → Greenwood Elementary",
                timestamp: calendar.date(byAdding: .minute, value: -10, to: now)!,
                type: .started,
                schoolRunId: schoolRuns[0].id
            ),
            SchoolRunNotification(
                id: UUID(),
                title: "Arriving Soon",
                message: "You'll arrive at Greenwood Elementary in 2 minutes",
                timestamp: calendar.date(byAdding: .minute, value: -2, to: now)!,
                type: .arriving,
                schoolRunId: schoolRuns[0].id
            ),
            SchoolRunNotification(
                id: UUID(),
                title: "Drop-off Complete",
                message: "Successfully dropped off Ethan and Zoe at school",
                timestamp: now,
                type: .completed,
                schoolRunId: schoolRuns[0].id
            )
        ]
    }
    
    // MARK: - Family Settings Mock Data
    
    /// Generates mock family settings for the Mawere Family
    static func mockFamilySettings() -> FamilySettings {
        let (family, _, _) = mockMawereFamily()
        let calendar = Calendar.current
        
        return FamilySettings(
            familyId: family.id,
            notificationsEnabled: true,
            quietHoursStart: calendar.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!,
            quietHoursEnd: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!,
            allowChildMessaging: true,
            requireTaskApproval: false,
            pointsSystemEnabled: true,
            maxPointsPerTask: 25
        )
    }
    
    // MARK: - Error Scenarios
    
    /// Provides comprehensive mock error scenarios for testing error handling flows
    static func mockErrorScenarios() -> [MockError] {
        return [
            MockError(
                type: .network,
                title: "No Internet Connection",
                message: "Please check your internet connection and try again.",
                recoveryAction: "Retry"
            ),
            MockError(
                type: .authentication,
                title: "Sign In Failed",
                message: "Unable to sign in with Apple ID. Please try again.",
                recoveryAction: "Try Again"
            ),
            MockError(
                type: .validation,
                title: "Invalid Family Code",
                message: "The family code you entered is not valid. Please check and try again.",
                recoveryAction: "Enter Code Again"
            ),
            MockError(
                type: .permission,
                title: "Access Denied",
                message: "You don't have permission to perform this action.",
                recoveryAction: "Contact Family Admin"
            ),
            MockError(
                type: .notFound,
                title: "Family Not Found",
                message: "No family found with that code. Please check the code and try again.",
                recoveryAction: "Try Different Code"
            ),
            MockError(
                type: .serverError,
                title: "Server Error",
                message: "Something went wrong on our end. Please try again later.",
                recoveryAction: "Try Again Later"
            )
        ]
    }
    
    /// Provides error scenarios for testing error handling (legacy method)
    static func errorScenarios() -> [(description: String, shouldSucceed: Bool)] {
        return [
            ("Valid family creation", true),
            ("Duplicate family code", false),
            ("Invalid family name", false),
            ("Network unavailable", false),
            ("Authentication failed", false),
            ("Parent Admin already exists", false)
        ]
    }
    
    // MARK: - Comprehensive Mock Data Sets
    
    /// Generates a complete mock data set for the prototype
    static func completePrototypeDataSet() -> (
        family: Family,
        users: [UserProfile],
        memberships: [Membership],
        calendarEvents: [CalendarEvent],
        tasks: [FamilyTask],
        messages: [FamilyMessage],
        schoolRuns: [SchoolRun],
        settings: FamilySettings,
        errors: [MockError]
    ) {
        let (family, users, memberships) = mockMawereFamily()
        
        return (
            family: family,
            users: users,
            memberships: memberships,
            calendarEvents: mockCalendarEvents(),
            tasks: mockFamilyTasks(),
            messages: mockFamilyMessages(),
            schoolRuns: mockSchoolRuns(),
            settings: mockFamilySettings(),
            errors: mockErrorScenarios()
        )
    }
    
    /// Generates mock data filtered by user role for appropriate access levels
    static func mockDataForRole(_ role: Role) -> (
        calendarEvents: [CalendarEvent],
        tasks: [FamilyTask],
        messages: [FamilyMessage],
        schoolRuns: [SchoolRun]
    ) {
        let allEvents = mockCalendarEvents()
        let allTasks = mockFamilyTasks()
        let allMessages = mockFamilyMessages()
        let allSchoolRuns = mockSchoolRuns()
        
        switch role {
        case .parentAdmin, .adult:
            // Full access to all data
            return (allEvents, allTasks, allMessages, allSchoolRuns)
            
        case .kid:
            // Limited access - only their own tasks and family events
            let (_, users, _) = mockMawereFamily()
            let kidIds = users.filter { user in
                // Assuming Ethan and Zoe are kids (indices 2 and 3)
                return user.displayName.contains("Ethan") || user.displayName.contains("Zoe")
            }.map { $0.id }
            
            let kidTasks = allTasks.filter { kidIds.contains($0.assignedTo) }
            let familyEvents = allEvents.filter { $0.type == .familyActivity || $0.type == .birthday }
            
            return (familyEvents, kidTasks, allMessages, allSchoolRuns)
            
        case .visitor:
            // Very limited access - only announcements and family activities
            let visitorEvents = allEvents.filter { $0.type == .familyActivity }
            let visitorMessages = allMessages.filter { $0.type == .announcement }
            
            return (visitorEvents, [], visitorMessages, [])
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension MockDataGenerator {
    /// Quick access to mock data for SwiftUI previews
    static let previewFamily = mockMawereFamily().family
    static let previewUsers = mockMawereFamily().users
    static let previewMemberships = mockMawereFamily().memberships
    static let previewCurrentUser = mockAuthenticatedUser()
    static let previewCalendarEvents = mockCalendarEvents()
    static let previewTasks = mockFamilyTasks()
    static let previewMessages = mockFamilyMessages()
    static let previewSchoolRuns = mockSchoolRuns()
    static let previewSettings = mockFamilySettings()
    static let previewErrors = mockErrorScenarios()
    
    /// Complete data set for comprehensive previews
    static let previewDataSet = completePrototypeDataSet()
    
    /// Role-specific preview data
    static let previewAdminData = mockDataForRole(.parentAdmin)
    static let previewKidData = mockDataForRole(.kid)
    static let previewVisitorData = mockDataForRole(.visitor)
}
#endif