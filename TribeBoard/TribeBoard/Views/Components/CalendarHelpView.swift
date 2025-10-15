import SwiftUI

/// Comprehensive help and documentation view for calendar features
struct CalendarHelpView: View {
    @State private var selectedSection: HelpSection = .gettingStarted
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText, placeholder: "Search help topics...")
                    .padding()
                
                HStack(spacing: 0) {
                    // Sidebar
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(HelpSection.allCases, id: \.self) { section in
                            HelpSectionButton(
                                section: section,
                                isSelected: selectedSection == section
                            ) {
                                selectedSection = section
                                CalendarHapticManager.shared.lightImpact()
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .frame(width: 200)
                    .background(Color(.systemGray6))
                    
                    // Content Area
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HelpContentView(section: selectedSection, searchText: searchText)
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Calendar Help")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss help view
                    }
                }
            }
        }
    }
}

// MARK: - Help Sections

enum HelpSection: String, CaseIterable {
    case gettingStarted = "Getting Started"
    case creatingEvents = "Creating Events"
    case managingEvents = "Managing Events"
    case familySharing = "Family Sharing"
    case appleCalendarSync = "Apple Calendar Sync"
    case privacySettings = "Privacy Settings"
    case troubleshooting = "Troubleshooting"
    case shortcuts = "Shortcuts & Tips"
    case accessibility = "Accessibility"
    case backup = "Backup & Restore"
    
    var icon: String {
        switch self {
        case .gettingStarted: return "play.circle"
        case .creatingEvents: return "plus.circle"
        case .managingEvents: return "pencil.circle"
        case .familySharing: return "person.2.circle"
        case .appleCalendarSync: return "arrow.clockwise.circle"
        case .privacySettings: return "lock.circle"
        case .troubleshooting: return "wrench.and.screwdriver"
        case .shortcuts: return "command.circle"
        case .accessibility: return "accessibility.circle"
        case .backup: return "externaldrive.badge.icloud"
        }
    }
}

// MARK: - Help Section Button

struct HelpSectionButton: View {
    let section: HelpSection
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(section.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(section.rawValue)
        .accessibilityHint(isSelected ? "Currently selected section" : "Tap to view \(section.rawValue.lowercased()) help")
    }
}

// MARK: - Help Content View

struct HelpContentView: View {
    let section: HelpSection
    let searchText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section Header
            HStack {
                Image(systemName: section.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(section.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // Section Content
            switch section {
            case .gettingStarted:
                GettingStartedContent()
            case .creatingEvents:
                CreatingEventsContent()
            case .managingEvents:
                ManagingEventsContent()
            case .familySharing:
                FamilySharingContent()
            case .appleCalendarSync:
                AppleCalendarSyncContent()
            case .privacySettings:
                PrivacySettingsContent()
            case .troubleshooting:
                TroubleshootingContent()
            case .shortcuts:
                ShortcutsContent()
            case .accessibility:
                AccessibilityContent()
            case .backup:
                BackupContent()
            }
        }
    }
}

// MARK: - Content Sections

struct GettingStartedContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpArticle(
                title: "Welcome to TribeBoard Calendar",
                content: """
                The TribeBoard Calendar helps you manage both personal and family events in one place. You can create private events that only you can see, or share events with your entire family.
                
                Key features:
                • Create and manage events
                • Share events with family members
                • Sync with Apple Calendar
                • Set privacy levels for events
                • Access calendar across all your devices
                """
            )
            
            HelpArticle(
                title: "Your First Event",
                content: """
                To create your first event:
                
                1. Tap the + button in the top right corner
                2. Enter your event title
                3. Set the date and time
                4. Choose privacy level (Personal or Family Shared)
                5. Add location and notes if needed
                6. Tap "Create Event"
                
                Your event will appear in the calendar and sync across your devices.
                """
            )
            
            QuickTipCard(
                title: "Pro Tip",
                tip: "Use the calendar widget on your dashboard for quick access to today's events and creating new ones."
            )
        }
    }
}

struct CreatingEventsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpArticle(
                title: "Event Creation Options",
                content: """
                When creating an event, you have several options:
                
                **Title**: Give your event a descriptive name
                **Date & Time**: Set when your event starts and ends
                **All Day**: Toggle for events that last the entire day
                **Location**: Add where the event takes place
                **Notes**: Include additional details or reminders
                **Privacy Level**: Choose who can see the event
                """
            )
            
            HelpArticle(
                title: "Privacy Levels Explained",
                content: """
                **Personal Events**: Only visible to you
                • Perfect for personal appointments, reminders, or private activities
                • Syncs to your personal Apple Calendar
                • Other family members cannot see these events
                
                **Family Shared Events**: Visible to all family members
                • Great for family activities, appointments, or important dates
                • All family members can see and receive notifications
                • Appears in the family calendar view
                """
            )
            
            StepByStepGuide(
                title: "Creating an Event Step-by-Step",
                steps: [
                    "Tap the + button or select a date on the calendar",
                    "Enter your event title",
                    "Set the start and end date/time",
                    "Choose privacy level (Personal or Family Shared)",
                    "Add location if applicable",
                    "Include any notes or details",
                    "Tap 'Create Event' to save"
                ]
            )
        }
    }
}

struct ManagingEventsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpArticle(
                title: "Editing Events",
                content: """
                To edit an existing event:
                
                1. Tap on the event in your calendar
                2. Tap "Edit" in the event details
                3. Make your changes
                4. Tap "Save" to update the event
                
                Changes will sync across all your devices and notify family members if it's a shared event.
                """
            )
            
            HelpArticle(
                title: "Deleting Events",
                content: """
                To delete an event:
                
                1. Tap on the event
                2. Tap "Delete" in the event details
                3. Confirm the deletion
                
                **Note**: Deleting a family shared event will remove it for all family members.
                """
            )
            
            HelpArticle(
                title: "Event Filters",
                content: """
                Use the filter buttons to view different types of events:
                
                • **All Events**: Shows both personal and family events
                • **Family**: Shows only shared family events
                • **Personal**: Shows only your personal events
                
                This helps you focus on the events that matter most at any given time.
                """
            )
        }
    }
}

struct FamilySharingContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpArticle(
                title: "How Family Sharing Works",
                content: """
                Family sharing allows all family members to see and manage shared events together. When you create a family shared event, it becomes visible to everyone in your family.
                
                **Who can do what:**
                • All family members can view shared events
                • Event creators can edit and delete their events
                • Family admins have additional permissions
                """
            )
            
            HelpArticle(
                title: "Converting Personal to Family Events",
                content: """
                You can share a personal event with your family:
                
                1. Tap on your personal event
                2. Tap "Share with Family"
                3. Confirm the action
                
                The event will now be visible to all family members.
                """
            )
            
            WarningCard(
                title: "Privacy Note",
                warning: "Once you share an event with your family, all family members will be able to see the event details including title, time, location, and notes."
            )
        }
    }
}

struct AppleCalendarSyncContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpArticle(
                title: "Setting Up Apple Calendar Sync",
                content: """
                Sync your TribeBoard events with Apple Calendar to access them across all your Apple devices.
                
                **To enable sync:**
                1. Go to Calendar Settings
                2. Tap "Enable Apple Calendar Sync"
                3. Grant calendar permissions when prompted
                4. Choose sync preferences
                
                TribeBoard will create a dedicated calendar in your Apple Calendar app.
                """
            )
            
            HelpArticle(
                title: "What Gets Synced",
                content: """
                **Personal Events**: Sync to your personal Apple Calendar
                **Family Events**: Sync to a shared family calendar (if enabled)
                
                **Sync includes:**
                • Event title, date, and time
                • Location and notes
                • Event updates and deletions
                """
            )
            
            TroubleshootingCard(
                title: "Sync Issues",
                problems: [
                    "Events not appearing in Apple Calendar",
                    "Changes not syncing between apps",
                    "Duplicate events appearing"
                ],
                solutions: [
                    "Check calendar permissions in Settings",
                    "Try manual sync from Calendar Settings",
                    "Disable and re-enable sync to refresh"
                ]
            )
        }
    }
}

struct PrivacySettingsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpArticle(
                title: "Understanding Privacy Levels",
                content: """
                TribeBoard gives you complete control over who can see your events:
                
                **Personal Events (Purple indicator)**
                • Only visible to you
                • Perfect for private appointments, personal reminders
                • Sync to your personal Apple Calendar only
                
                **Family Shared Events (Blue indicator)**
                • Visible to all family members
                • Great for family activities, shared appointments
                • Can be managed by family admins
                """
            )
            
            HelpArticle(
                title: "Changing Privacy Levels",
                content: """
                You can change an event's privacy level after creation:
                
                **To make personal event family shared:**
                1. Open the event details
                2. Tap "Share with Family"
                3. Confirm the action
                
                **To make family event personal:**
                1. Open the event details
                2. Tap "Make Personal"
                3. Confirm (this removes it from family view)
                """
            )
        }
    }
}

struct TroubleshootingContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TroubleshootingCard(
                title: "Common Issues",
                problems: [
                    "Events not syncing",
                    "Calendar permissions denied",
                    "Events appearing twice",
                    "Family events not visible"
                ],
                solutions: [
                    "Check internet connection and try manual sync",
                    "Go to Settings > Privacy > Calendars and enable for TribeBoard",
                    "Disable and re-enable Apple Calendar sync",
                    "Ensure you're part of the family and have proper permissions"
                ]
            )
            
            HelpArticle(
                title: "Getting More Help",
                content: """
                If you're still experiencing issues:
                
                1. Try restarting the app
                2. Check for app updates in the App Store
                3. Contact support through Settings > Help & Support
                4. Visit our online help center for detailed guides
                
                When contacting support, please include:
                • Your device model and iOS version
                • Description of the issue
                • Steps you've already tried
                """
            )
        }
    }
}

struct ShortcutsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpArticle(
                title: "Calendar Shortcuts",
                content: """
                Speed up your calendar workflow with these shortcuts:
                
                **Quick Actions:**
                • Tap + to create event for selected date
                • Pull down to refresh and sync
                • Tap "Today" to jump to current date
                • Long press on date for quick event creation
                
                **Navigation:**
                • Swipe left/right to change weeks
                • Tap date to select and view events
                • Use filter buttons to focus on specific event types
                """
            )
            
            HelpArticle(
                title: "Calendar Widget",
                content: """
                Add the calendar widget to your dashboard for quick access:
                
                • View today's events at a glance
                • Quick create button for new events
                • One-tap sync with Apple Calendar
                • Direct access to full calendar view
                """
            )
        }
    }
}

struct AccessibilityContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpArticle(
                title: "Accessibility Features",
                content: """
                TribeBoard Calendar is designed to be accessible to everyone:
                
                **VoiceOver Support:**
                • All calendar elements have descriptive labels
                • Event details are announced clearly
                • Navigation is fully accessible with VoiceOver
                
                **Dynamic Type:**
                • Text scales with your preferred reading size
                • Maintains readability at all sizes
                
                **High Contrast:**
                • Supports high contrast mode
                • Clear visual indicators for different event types
                """
            )
            
            HelpArticle(
                title: "Keyboard Navigation",
                content: """
                Navigate the calendar using external keyboards:
                
                • Tab to move between elements
                • Space or Enter to select
                • Arrow keys to navigate calendar dates
                • Escape to close sheets and modals
                """
            )
        }
    }
}

struct BackupContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpArticle(
                title: "Calendar Backup",
                content: """
                Protect your calendar data with automatic backups:
                
                **What's backed up:**
                • All your events (personal and family)
                • Calendar settings and preferences
                • Sync configurations
                
                **Backup locations:**
                • iCloud (automatic, encrypted)
                • Local device storage
                """
            )
            
            StepByStepGuide(
                title: "Creating a Manual Backup",
                steps: [
                    "Go to Calendar Settings",
                    "Tap 'Backup & Restore'",
                    "Tap 'Create Backup'",
                    "Wait for backup to complete",
                    "Backup is saved to iCloud and locally"
                ]
            )
            
            HelpArticle(
                title: "Restoring from Backup",
                content: """
                If you need to restore your calendar data:
                
                1. Go to Calendar Settings > Backup & Restore
                2. Select a backup from the list
                3. Choose restore options (replace or merge)
                4. Confirm the restore operation
                5. Wait for restore to complete
                
                **Note**: Restoring will sync changes to all your devices.
                """
            )
        }
    }
}

// MARK: - Supporting Components

struct HelpArticle: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct QuickTipCard: View {
    let title: String
    let tip: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(tip)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
}

struct WarningCard: View {
    let title: String
    let warning: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(warning)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TroubleshootingCard: View {
    let title: String
    let problems: [String]
    let solutions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Common Problems:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(Array(problems.enumerated()), id: \.offset) { index, problem in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(problem)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Solutions:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(Array(solutions.enumerated()), id: \.offset) { index, solution in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                        Text(solution)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StepByStepGuide: View {
    let title: String
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.blue))
                        
                        Text(step)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    CalendarHelpView()
        .previewEnvironment()
}