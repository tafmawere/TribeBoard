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
struct FamilyTask: Codable {
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
    
    enum TaskStatus: String, CaseIterable, Codable {
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
    
    enum TaskCategory: String, CaseIterable, Codable {
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
struct FamilyMessage: Codable {
    let id: UUID
    let content: String
    let sender: UUID
    let timestamp: Date
    let type: MessageType
    let isRead: Bool
    let attachmentUrl: URL?
    
    enum MessageType: String, CaseIterable, Codable {
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

// Note: SchoolRun and RunStatus types are now defined in their own dedicated files:
// - SchoolRun.swift
// - RunStatus.swift
// - RunStop.swift
// This provides a more comprehensive implementation for the school run scheduler feature.

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

/// Demo scenario types for different user experiences
enum DemoScenario: String, CaseIterable {
    case newUserOnboarding = "new_user_onboarding"
    case existingUserLogin = "existing_user_login"
    case familyAdminTasks = "family_admin_tasks"
    case childUserExperience = "child_user_experience"
    case completeFeatureTour = "complete_feature_tour"
    case homeLifeMealPlanning = "home_life_meal_planning"
    case homeLifeGroceryShopping = "home_life_grocery_shopping"
    case homeLifeTaskManagement = "home_life_task_management"
    case homeLifeCompleteWorkflow = "home_life_complete_workflow"
    
    var displayName: String {
        switch self {
        case .newUserOnboarding: return "New User Onboarding"
        case .existingUserLogin: return "Existing User Login"
        case .familyAdminTasks: return "Family Admin Tasks"
        case .childUserExperience: return "Child User Experience"
        case .completeFeatureTour: return "Complete Feature Tour"
        case .homeLifeMealPlanning: return "Home Life - Meal Planning"
        case .homeLifeGroceryShopping: return "Home Life - Grocery Shopping"
        case .homeLifeTaskManagement: return "Home Life - Task Management"
        case .homeLifeCompleteWorkflow: return "Home Life - Complete Workflow"
        }
    }
    
    var estimatedDuration: TimeInterval {
        switch self {
        case .newUserOnboarding: return 5 * 60 // 5 minutes
        case .existingUserLogin: return 2 * 60 // 2 minutes
        case .familyAdminTasks: return 8 * 60 // 8 minutes
        case .childUserExperience: return 4 * 60 // 4 minutes
        case .completeFeatureTour: return 15 * 60 // 15 minutes
        case .homeLifeMealPlanning: return 6 * 60 // 6 minutes
        case .homeLifeGroceryShopping: return 7 * 60 // 7 minutes
        case .homeLifeTaskManagement: return 5 * 60 // 5 minutes
        case .homeLifeCompleteWorkflow: return 20 * 60 // 20 minutes
        }
    }
}

/// Comprehensive demo showcase data structure
struct DemoShowcaseData {
    let family: Family
    let users: [UserProfile]
    let memberships: [Membership]
    let calendarEvents: [CalendarEvent]
    let tasks: [FamilyTask]
    let messages: [FamilyMessage]
    let noticeboardPosts: [NoticeboardPost]
    let schoolRuns: [SchoolRun]
    let settings: FamilySettings
}

/// Demo scenario data structure
struct DemoScenarioData {
    let family: Family
    let users: [UserProfile]
    let memberships: [Membership]
    let currentUser: UserProfile
    let calendarEvents: [CalendarEvent]
    let tasks: [FamilyTask]
    let messages: [FamilyMessage]
    let schoolRuns: [SchoolRun]
}

/// Demo reset data structure
struct DemoResetData {
    let shouldClearUserData: Bool
    let shouldResetToOnboarding: Bool
    let shouldClearNotifications: Bool
    let defaultScenario: DemoScenario
}


/// Mock error data structure for prototype
struct MockErrorData {
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
enum UserJourneyScenario: String, CaseIterable, Codable {
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
    
    // MARK: - Demo-Specific Data Generation
    
    /// Generates comprehensive demo data that showcases all app features
    static func mockDemoShowcaseData() -> DemoShowcaseData {
        let (family, users, memberships) = mockMawereFamily()
        
        return DemoShowcaseData(
            family: family,
            users: users,
            memberships: memberships,
            calendarEvents: mockCalendarEvents(),
            tasks: mockFamilyTasks(),
            messages: mockFamilyMessages(),
            noticeboardPosts: mockNoticeboardPosts(),
            schoolRuns: mockSchoolRuns(),
            settings: mockFamilySettings(for: family.id)
        )
    }
    
    /// Generates role-specific mock data for different user experiences
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
        case .parentAdmin:
            // Admins see everything
            return (allEvents, allTasks, allMessages, allSchoolRuns)
            
        case .adult:
            // Adults see most things but not admin-specific tasks
            let filteredTasks = allTasks.filter { $0.category != .family || $0.points <= 15 }
            return (allEvents, filteredTasks, allMessages, allSchoolRuns)
            
        case .kid:
            // Kids see only their own tasks and family events
            let (_, users, _) = mockMawereFamily()
            let childUserId = users[2].id // Ethan
            let filteredEvents = allEvents.filter { $0.participants.contains(childUserId) || $0.type == .familyActivity }
            let filteredTasks = allTasks.filter { $0.assignedTo == childUserId }
            let filteredMessages = allMessages.filter { $0.type != .announcement || $0.sender == childUserId }
            // Note: Filtering school runs by passengers not implemented in new structure
            let filteredSchoolRuns = allSchoolRuns
            
            return (filteredEvents, filteredTasks, filteredMessages, filteredSchoolRuns)
            
        case .visitor:
            // Visitors see limited information
            let publicEvents = allEvents.filter { $0.type == .familyActivity || $0.type == .birthday }
            let publicMessages = allMessages.filter { $0.type == .announcement }
            
            return (publicEvents, [], publicMessages, [])
        }
    }
    
    /// Generates demo data for specific user journey scenarios
    static func mockDataForDemoScenario(_ scenario: DemoScenario) -> DemoScenarioData {
        let (family, users, memberships) = mockMawereFamily()
        
        switch scenario {
        case .newUserOnboarding:
            return DemoScenarioData(
                family: family,
                users: users,
                memberships: memberships,
                currentUser: users[0], // Start as admin for demo
                calendarEvents: [],
                tasks: [],
                messages: [],
                schoolRuns: []
            )
            
        case .existingUserLogin:
            return DemoScenarioData(
                family: family,
                users: users,
                memberships: memberships,
                currentUser: users[1], // Grace - existing adult user
                calendarEvents: mockCalendarEvents(),
                tasks: mockFamilyTasks(),
                messages: mockFamilyMessages(),
                schoolRuns: mockSchoolRuns()
            )
            
        case .familyAdminTasks:
            return DemoScenarioData(
                family: family,
                users: users,
                memberships: memberships,
                currentUser: users[0], // Tafadzwa - admin
                calendarEvents: mockCalendarEvents(),
                tasks: mockFamilyTasks(),
                messages: mockFamilyMessages(),
                schoolRuns: mockSchoolRuns()
            )
            
        case .childUserExperience:
            let childData = mockDataForRole(.kid)
            return DemoScenarioData(
                family: family,
                users: users,
                memberships: memberships,
                currentUser: users[2], // Ethan - child user
                calendarEvents: childData.calendarEvents,
                tasks: childData.tasks,
                messages: childData.messages,
                schoolRuns: childData.schoolRuns
            )
            
        case .completeFeatureTour:
            return DemoScenarioData(
                family: family,
                users: users,
                memberships: memberships,
                currentUser: users[0], // Admin for full access
                calendarEvents: mockCalendarEvents(),
                tasks: mockFamilyTasks(),
                messages: mockFamilyMessages(),
                schoolRuns: mockSchoolRuns()
            )
            
        case .homeLifeMealPlanning:
            return DemoScenarioData(
                family: family,
                users: users,
                memberships: memberships,
                currentUser: users[1], // Grace - meal planning parent
                calendarEvents: mockCalendarEvents(),
                tasks: mockFamilyTasks(),
                messages: mockFamilyMessages(),
                schoolRuns: mockSchoolRuns()
            )
            
        case .homeLifeGroceryShopping:
            return DemoScenarioData(
                family: family,
                users: users,
                memberships: memberships,
                currentUser: users[0], // Tafadzwa - shopping coordinator
                calendarEvents: mockCalendarEvents(),
                tasks: mockFamilyTasks(),
                messages: mockFamilyMessages(),
                schoolRuns: mockSchoolRuns()
            )
            
        case .homeLifeTaskManagement:
            return DemoScenarioData(
                family: family,
                users: users,
                memberships: memberships,
                currentUser: users[0], // Tafadzwa - task manager
                calendarEvents: mockCalendarEvents(),
                tasks: mockFamilyTasks(),
                messages: mockFamilyMessages(),
                schoolRuns: mockSchoolRuns()
            )
            
        case .homeLifeCompleteWorkflow:
            return DemoScenarioData(
                family: family,
                users: users,
                memberships: memberships,
                currentUser: users[1], // Grace - complete workflow demo
                calendarEvents: mockCalendarEvents(),
                tasks: mockFamilyTasks(),
                messages: mockFamilyMessages(),
                schoolRuns: mockSchoolRuns()
            )
        }
    }
    
    /// Generates mock family settings
    static func mockFamilySettings(for familyId: UUID) -> FamilySettings {
        let calendar = Calendar.current
        let quietStart = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!
        let quietEnd = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        
        return FamilySettings(
            familyId: familyId,
            notificationsEnabled: true,
            quietHoursStart: quietStart,
            quietHoursEnd: quietEnd,
            allowChildMessaging: true,
            requireTaskApproval: false,
            pointsSystemEnabled: true,
            maxPointsPerTask: 25
        )
    }
    
    /// Generates mock error scenarios for demo purposes
    static func mockErrorScenarios() -> [MockErrorScenario] {
        return [
            .networkOutage,
            .authenticationIssues,
            .validationProblems,
            .permissionDenials,
            .syncConflicts,
            .prototypeDemo
        ]
    }
    
    /// Generates demo reset data to return app to initial state
    static func mockInitialDemoState() -> DemoResetData {
        return DemoResetData(
            shouldClearUserData: true,
            shouldResetToOnboarding: true,
            shouldClearNotifications: true,
            defaultScenario: .newUserOnboarding
        )
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
    
    // MARK: - School Run Mock Data
    
    /// Generates comprehensive mock school runs with diverse scenarios
    static func mockSchoolRuns() -> [SchoolRun] {
        let calendar = Calendar.current
        let today = Date()
        
        var runs: [SchoolRun] = []
        
        // Today's runs
        runs.append(contentsOf: mockTodaysRuns(baseDate: today))
        
        // Upcoming runs
        runs.append(contentsOf: mockUpcomingRuns(baseDate: today))
        
        // Completed runs
        runs.append(contentsOf: mockCompletedRuns(baseDate: today))
        
        // Edge cases
        runs.append(contentsOf: mockEdgeCaseRuns(baseDate: today))
        
        return runs
    }
    
    /// Generates today's school runs with various statuses
    static func mockTodaysRuns(baseDate: Date = Date()) -> [SchoolRun] {
        let calendar = Calendar.current
        
        return [
            // Morning run - in progress
            SchoolRun(
                id: UUID(),
                title: "Morning School Drop-off",
                date: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: baseDate)!,
                route: [
                    RunStop(
                        name: "Home",
                        time: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: baseDate)!,
                        note: "Pick up Ethan and Zoe",
                        type: .pickup,
                        isCompleted: true,
                        task: "Pick up Ethan and Zoe",
                        estimatedMinutes: 5
                    ),
                    RunStop(
                        name: "Greenwood Elementary",
                        time: calendar.date(bySettingHour: 8, minute: 15, second: 0, of: baseDate)!,
                        note: "Drop off Zoe",
                        type: .dropoff,
                        isCompleted: true,
                        task: "Drop off Zoe",
                        estimatedMinutes: 10
                    ),
                    RunStop(
                        name: "Riverside Middle School",
                        time: calendar.date(bySettingHour: 8, minute: 30, second: 0, of: baseDate)!,
                        note: "Drop off Ethan",
                        type: .dropoff,
                        isCompleted: false,
                        task: "Drop off Ethan",
                        estimatedMinutes: 10
                    )
                ],
                status: .inProgress,
                createdAt: calendar.date(byAdding: .day, value: -1, to: baseDate)!,
                estimatedDuration: 30 * 60 // 30 minutes
            ),
            
            // Afternoon pickup - scheduled
            SchoolRun(
                id: UUID(),
                title: "Afternoon School Pickup",
                date: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: baseDate)!,
                route: [
                    RunStop(
                        name: "Greenwood Elementary",
                        time: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: baseDate)!,
                        note: "Pick up Zoe",
                        type: .pickup,
                        task: "Pick up Zoe",
                        estimatedMinutes: 10
                    ),
                    RunStop(
                        name: "Riverside Middle School",
                        time: calendar.date(bySettingHour: 15, minute: 45, second: 0, of: baseDate)!,
                        note: "Pick up Ethan",
                        type: .pickup,
                        task: "Pick up Ethan",
                        estimatedMinutes: 10
                    ),
                    RunStop(
                        name: "Home",
                        time: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: baseDate)!,
                        note: "Drop off kids",
                        type: .dropoff,
                        task: "Drop off kids",
                        estimatedMinutes: 5
                    )
                ],
                status: .scheduled,
                createdAt: calendar.date(byAdding: .day, value: -1, to: baseDate)!,
                estimatedDuration: 30 * 60 // 30 minutes
            )
        ]
    }
    
    /// Generates upcoming school runs for the next few days
    static func mockUpcomingRuns(baseDate: Date = Date()) -> [SchoolRun] {
        let calendar = Calendar.current
        
        return [
            // Tomorrow's morning run
            SchoolRun(
                id: UUID(),
                title: "Morning School Run",
                date: calendar.date(byAdding: .day, value: 1, to: baseDate)!,
                route: mockStandardMorningRoute(for: calendar.date(byAdding: .day, value: 1, to: baseDate)!),
                status: .scheduled,
                createdAt: baseDate,
                estimatedDuration: 35 * 60
            ),
            
            // Day after tomorrow - early dismissal
            SchoolRun(
                id: UUID(),
                title: "Early Dismissal Pickup",
                date: calendar.date(byAdding: .day, value: 2, to: baseDate)!,
                route: [
                    RunStop(
                        name: "Riverside Middle School",
                        time: calendar.date(byAdding: .day, value: 2, to: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: baseDate)!)!,
                        note: "Early dismissal - pick up Ethan",
                        type: .pickup,
                        task: "Early dismissal - pick up Ethan",
                        estimatedMinutes: 10
                    ),
                    RunStop(
                        name: "Greenwood Elementary",
                        time: calendar.date(byAdding: .day, value: 2, to: calendar.date(bySettingHour: 13, minute: 15, second: 0, of: baseDate)!)!,
                        note: "Pick up Zoe",
                        type: .pickup,
                        task: "Pick up Zoe",
                        estimatedMinutes: 10
                    ),
                    RunStop(
                        name: "Home",
                        time: calendar.date(byAdding: .day, value: 2, to: calendar.date(bySettingHour: 13, minute: 30, second: 0, of: baseDate)!)!,
                        note: "Home for lunch",
                        type: .dropoff,
                        task: "Home for lunch",
                        estimatedMinutes: 5
                    )
                ],
                status: .scheduled,
                createdAt: baseDate,
                estimatedDuration: 30 * 60
            ),
            
            // Weekend activity run
            SchoolRun(
                id: UUID(),
                title: "Soccer Practice & Piano Lesson",
                date: calendar.date(byAdding: .day, value: 5, to: baseDate)!,
                route: [
                    RunStop(
                        name: "Home",
                        time: calendar.date(byAdding: .day, value: 5, to: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseDate)!)!,
                        note: "Pick up Ethan for soccer",
                        type: .pickup,
                        task: "Pick up Ethan for soccer",
                        estimatedMinutes: 5
                    ),
                    RunStop(
                        name: "Riverside Soccer Fields",
                        time: calendar.date(byAdding: .day, value: 5, to: calendar.date(bySettingHour: 9, minute: 15, second: 0, of: baseDate)!)!,
                        note: "Drop off Ethan for practice",
                        type: .dropoff,
                        task: "Drop off Ethan for practice",
                        estimatedMinutes: 10
                    ),
                    RunStop(
                        name: "Home",
                        time: calendar.date(byAdding: .day, value: 5, to: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: baseDate)!)!,
                        note: "Pick up Zoe for piano",
                        type: .pickup,
                        task: "Pick up Zoe for piano",
                        estimatedMinutes: 5
                    ),
                    RunStop(
                        name: "Music Academy",
                        time: calendar.date(byAdding: .day, value: 5, to: calendar.date(bySettingHour: 9, minute: 45, second: 0, of: baseDate)!)!,
                        note: "Drop off Zoe for lesson",
                        type: .dropoff,
                        task: "Drop off Zoe for lesson",
                        estimatedMinutes: 10
                    ),
                    RunStop(
                        name: "Riverside Soccer Fields",
                        time: calendar.date(byAdding: .day, value: 5, to: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: baseDate)!)!,
                        note: "Pick up Ethan",
                        type: .pickup,
                        task: "Pick up Ethan",
                        estimatedMinutes: 5
                    ),
                    RunStop(
                        name: "Music Academy",
                        time: calendar.date(byAdding: .day, value: 5, to: calendar.date(bySettingHour: 10, minute: 45, second: 0, of: baseDate)!)!,
                        note: "Pick up Zoe",
                        type: .pickup,
                        task: "Pick up Zoe",
                        estimatedMinutes: 5
                    ),
                    RunStop(
                        name: "Home",
                        time: calendar.date(byAdding: .day, value: 5, to: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: baseDate)!)!,
                        note: "Back home",
                        type: .dropoff,
                        task: "Back home",
                        estimatedMinutes: 10
                    )
                ],
                status: .scheduled,
                createdAt: baseDate,
                estimatedDuration: 120 * 60 // 2 hours
            )
        ]
    }
    
    /// Generates completed school runs from recent past
    static func mockCompletedRuns(baseDate: Date = Date()) -> [SchoolRun] {
        let calendar = Calendar.current
        
        return [
            // Yesterday's completed runs
            SchoolRun(
                id: UUID(),
                title: "Morning School Drop-off",
                date: calendar.date(byAdding: .day, value: -1, to: baseDate)!,
                route: mockCompletedRoute(for: calendar.date(byAdding: .day, value: -1, to: baseDate)!),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -2, to: baseDate)!,
                estimatedDuration: 30 * 60
            ),
            
            SchoolRun(
                id: UUID(),
                title: "Afternoon School Pickup",
                date: calendar.date(byAdding: .day, value: -1, to: baseDate)!,
                route: mockCompletedRoute(for: calendar.date(byAdding: .day, value: -1, to: baseDate)!, isAfternoon: true),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -2, to: baseDate)!,
                estimatedDuration: 25 * 60
            ),
            
            // Last week's special run
            SchoolRun(
                id: UUID(),
                title: "Field Trip Pickup",
                date: calendar.date(byAdding: .day, value: -7, to: baseDate)!,
                route: [
                    RunStop(
                        name: "Science Museum",
                        time: calendar.date(byAdding: .day, value: -7, to: calendar.date(bySettingHour: 14, minute: 30, second: 0, of: baseDate)!)!,
                        note: "Pick up Ethan from field trip",
                        type: .pickup,
                        isCompleted: true,
                        task: "Pick up Ethan from field trip",
                        estimatedMinutes: 15
                    ),
                    RunStop(
                        name: "Home",
                        time: calendar.date(byAdding: .day, value: -7, to: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: baseDate)!)!,
                        note: "Drop off at home",
                        type: .dropoff,
                        isCompleted: true,
                        task: "Drop off at home",
                        estimatedMinutes: 10
                    )
                ],
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -8, to: baseDate)!,
                estimatedDuration: 30 * 60
            )
        ]
    }
    
    /// Generates edge case runs for testing various scenarios
    static func mockEdgeCaseRuns(baseDate: Date = Date()) -> [SchoolRun] {
        let calendar = Calendar.current
        
        return [
            // Empty run (no stops)
            SchoolRun(
                id: UUID(),
                title: "Empty Test Run",
                date: calendar.date(byAdding: .day, value: 3, to: baseDate)!,
                route: [],
                status: .scheduled,
                createdAt: baseDate,
                estimatedDuration: 0
            ),
            
            // Cancelled run
            SchoolRun(
                id: UUID(),
                title: "Cancelled Doctor Appointment",
                date: calendar.date(byAdding: .day, value: -2, to: baseDate)!,
                route: [
                    RunStop(
                        name: "Home",
                        time: calendar.date(byAdding: .day, value: -2, to: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: baseDate)!)!,
                        note: "Pick up Zoe",
                        type: .pickup,
                        task: "Pick up Zoe",
                        estimatedMinutes: 5
                    ),
                    RunStop(
                        name: "Pediatric Clinic",
                        time: calendar.date(byAdding: .day, value: -2, to: calendar.date(bySettingHour: 10, minute: 15, second: 0, of: baseDate)!)!,
                        note: "Doctor appointment",
                        type: .dropoff,
                        task: "Doctor appointment",
                        estimatedMinutes: 60
                    )
                ],
                status: .cancelled,
                createdAt: calendar.date(byAdding: .day, value: -3, to: baseDate)!,
                estimatedDuration: 60 * 60
            ),
            
            // Single stop run
            SchoolRun(
                id: UUID(),
                title: "Quick Library Drop-off",
                date: calendar.date(byAdding: .day, value: 4, to: baseDate)!,
                route: [
                    RunStop(
                        name: "Public Library",
                        time: calendar.date(byAdding: .day, value: 4, to: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: baseDate)!)!,
                        note: "Return books",
                        type: .dropoff,
                        task: "Return books",
                        estimatedMinutes: 15
                    )
                ],
                status: .scheduled,
                createdAt: baseDate,
                estimatedDuration: 15 * 60
            ),
            
            // Past date run (should not normally happen)
            SchoolRun(
                id: UUID(),
                title: "Old Scheduled Run",
                date: calendar.date(byAdding: .day, value: -10, to: baseDate)!,
                route: mockStandardMorningRoute(for: calendar.date(byAdding: .day, value: -10, to: baseDate)!),
                status: .scheduled,
                createdAt: calendar.date(byAdding: .day, value: -11, to: baseDate)!,
                estimatedDuration: 30 * 60
            ),
            
            // Long duration run with many stops
            SchoolRun(
                id: UUID(),
                title: "Multi-Activity Saturday",
                date: calendar.date(byAdding: .day, value: 6, to: baseDate)!,
                route: mockComplexRoute(for: calendar.date(byAdding: .day, value: 6, to: baseDate)!),
                status: .scheduled,
                createdAt: baseDate,
                estimatedDuration: 180 * 60 // 3 hours
            )
        ]
    }
    
    /// Generates a standard morning school route
    static func mockStandardMorningRoute(for date: Date) -> [RunStop] {
        let calendar = Calendar.current
        
        return [
            RunStop(
                name: "Home",
                time: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date)!,
                note: "Pick up kids",
                type: .pickup,
                task: "Pick up kids",
                estimatedMinutes: 5
            ),
            RunStop(
                name: "Greenwood Elementary",
                time: calendar.date(bySettingHour: 8, minute: 15, second: 0, of: date)!,
                note: "Drop off Zoe",
                type: .dropoff,
                task: "Drop off Zoe",
                estimatedMinutes: 10
            ),
            RunStop(
                name: "Riverside Middle School",
                time: calendar.date(bySettingHour: 8, minute: 30, second: 0, of: date)!,
                note: "Drop off Ethan",
                type: .dropoff,
                task: "Drop off Ethan",
                estimatedMinutes: 10
            )
        ]
    }
    
    /// Generates a completed route with all stops marked as completed
    static func mockCompletedRoute(for date: Date, isAfternoon: Bool = false) -> [RunStop] {
        let calendar = Calendar.current
        let baseHour = isAfternoon ? 15 : 8
        
        return [
            RunStop(
                name: isAfternoon ? "Greenwood Elementary" : "Home",
                time: calendar.date(bySettingHour: baseHour, minute: 30, second: 0, of: date)!,
                note: isAfternoon ? "Pick up Zoe" : "Pick up kids",
                type: isAfternoon ? .pickup : .pickup,
                isCompleted: true,
                task: isAfternoon ? "Pick up Zoe" : "Pick up kids",
                estimatedMinutes: isAfternoon ? 10 : 5
            ),
            RunStop(
                name: isAfternoon ? "Riverside Middle School" : "Greenwood Elementary",
                time: calendar.date(bySettingHour: baseHour, minute: 45, second: 0, of: date)!,
                note: isAfternoon ? "Pick up Ethan" : "Drop off Zoe",
                type: isAfternoon ? .pickup : .dropoff,
                isCompleted: true,
                task: isAfternoon ? "Pick up Ethan" : "Drop off Zoe",
                estimatedMinutes: 10
            ),
            RunStop(
                name: isAfternoon ? "Home" : "Riverside Middle School",
                time: calendar.date(bySettingHour: baseHour + (isAfternoon ? 1 : 0), minute: 0, second: 0, of: date)!,
                note: isAfternoon ? "Drop off kids" : "Drop off Ethan",
                type: .dropoff,
                isCompleted: true,
                task: isAfternoon ? "Drop off kids" : "Drop off Ethan",
                estimatedMinutes: isAfternoon ? 5 : 10
            )
        ]
    }
    
    /// Generates a complex route with many stops for testing
    static func mockComplexRoute(for date: Date) -> [RunStop] {
        let calendar = Calendar.current
        
        return [
            RunStop(
                name: "Home",
                time: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)!,
                note: "Start of busy day",
                type: .pickup,
                task: "Start of busy day",
                estimatedMinutes: 5
            ),
            RunStop(
                name: "Soccer Fields",
                time: calendar.date(bySettingHour: 9, minute: 15, second: 0, of: date)!,
                note: "Ethan's soccer practice",
                type: .dropoff,
                task: "Ethan's soccer practice",
                estimatedMinutes: 10
            ),
            RunStop(
                name: "Dance Studio",
                time: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: date)!,
                note: "Zoe's dance class",
                type: .dropoff,
                task: "Zoe's dance class",
                estimatedMinutes: 10
            ),
            RunStop(
                name: "Grocery Store",
                time: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date)!,
                note: "Quick shopping",
                type: .dropoff,
                task: "Quick shopping",
                estimatedMinutes: 30
            ),
            RunStop(
                name: "Soccer Fields",
                time: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: date)!,
                note: "Pick up Ethan",
                type: .pickup,
                task: "Pick up Ethan",
                estimatedMinutes: 5
            ),
            RunStop(
                name: "Dance Studio",
                time: calendar.date(bySettingHour: 10, minute: 45, second: 0, of: date)!,
                note: "Pick up Zoe",
                type: .pickup,
                task: "Pick up Zoe",
                estimatedMinutes: 5
            ),
            RunStop(
                name: "Park",
                time: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: date)!,
                note: "Family picnic",
                type: .dropoff,
                task: "Family picnic",
                estimatedMinutes: 60
            ),
            RunStop(
                name: "Home",
                time: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!,
                note: "Back home for lunch",
                type: .dropoff,
                task: "Back home for lunch",
                estimatedMinutes: 10
            )
        ]
    }
    
    /// Generates school run scenarios for different family roles
    static func mockSchoolRunsForRole(_ role: Role) -> [SchoolRun] {
        let allRuns = mockSchoolRuns()
        
        switch role {
        case .parentAdmin, .adult:
            // Parents see all runs
            return allRuns
            
        case .kid:
            // Kids see only runs that involve them (simplified - show all for demo)
            return allRuns.filter { run in
                // In a real implementation, this would filter by child assignment
                !run.route.isEmpty
            }
            
        case .visitor:
            // Visitors see no school runs
            return []
        }
    }
    
    /// Generates school run notifications for testing
    static func mockSchoolRunNotifications() -> [SchoolRunNotification] {
        let runs = mockSchoolRuns()
        let calendar = Calendar.current
        let now = Date()
        
        return [
            SchoolRunNotification(
                id: UUID(),
                title: "School Run Started",
                message: "Morning school drop-off has begun",
                timestamp: calendar.date(byAdding: .minute, value: -15, to: now)!,
                type: .started,
                schoolRunId: runs.first?.id ?? UUID()
            ),
            SchoolRunNotification(
                id: UUID(),
                title: "Arriving Soon",
                message: "Arriving at Greenwood Elementary in 5 minutes",
                timestamp: calendar.date(byAdding: .minute, value: -5, to: now)!,
                type: .arriving,
                schoolRunId: runs.first?.id ?? UUID()
            ),
            SchoolRunNotification(
                id: UUID(),
                title: "Run Completed",
                message: "Afternoon pickup completed successfully",
                timestamp: calendar.date(byAdding: .hour, value: -2, to: now)!,
                type: .completed,
                schoolRunId: runs.first?.id ?? UUID()
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
        errors: [MockErrorScenario]
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

