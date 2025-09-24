# Design Document

## Overview

The School Run Scheduler is a comprehensive multi-screen feature that enables parents to create, manage, and execute structured school transportation runs. The system consists of 5 interconnected SwiftUI screens that follow TribeBoard's established design patterns while introducing new scheduling and execution workflows.

The architecture emphasizes local state management with placeholder data, ensuring the feature can demonstrate full UX flows without backend dependencies. All screens integrate seamlessly with TribeBoard's existing navigation structure, design system, and branding guidelines.

## Architecture

### Screen Flow Architecture

```
MainNavigationView
├── SchoolRunDashboardView (Entry Point)
│   ├── → ScheduleNewRunView (Create Flow)
│   ├── → ScheduledRunsListView (Browse Flow)
│   └── → RunDetailView (Review Flow)
│       └── → RunExecutionView (Execution Flow)
└── FloatingBottomNavigation (Persistent)
```

### Data Flow Architecture

```
SchoolRunSchedulerData (Static Model)
├── MockRunTemplates[]
├── MockChildrenProfiles[]
├── MockStopPresets[]
└── MockMapPlaceholders[]

SchoolRunState (Local State Management)
├── @StateObject runManager: SchoolRunManager
├── @State selectedRun: SchoolRun?
├── @State executionState: RunExecutionState
└── @State navigationPath: NavigationPath
```

### Component Hierarchy

```
SchoolRunScheduler Module
├── Views/
│   ├── SchoolRunDashboardView
│   ├── ScheduleNewRunView
│   ├── ScheduledRunsListView
│   ├── RunDetailView
│   └── RunExecutionView
├── Components/
│   ├── RunSummaryCard
│   ├── StopConfigurationRow
│   ├── MapPlaceholderView
│   ├── ProgressIndicator
│   └── ExecutionControls
├── Models/
│   ├── SchoolRun
│   ├── RunStop
│   ├── ChildProfile
│   └── RunExecutionState
└── Utilities/
    ├── SchoolRunManager
    ├── MockDataProvider
    └── ToastNotificationManager
```

## Components and Interfaces

### 1. SchoolRunDashboardView

**Purpose**: Main entry point providing overview of runs and primary navigation

**Layout Structure**:
```swift
NavigationStack {
    ScrollView {
        VStack(spacing: 24) {
            // Header with title
            HeaderSection(title: "School Runs")
            
            // Primary action buttons
            ActionButtonsSection()
            
            // Upcoming runs section
            UpcomingRunsSection(runs: upcomingRuns)
            
            // Past runs section
            PastRunsSection(runs: pastRuns)
        }
        .padding()
    }
    .navigationTitle("School Runs")
    .navigationBarHidden(true)
}
```

**Key Components**:
- **ActionButtonsSection**: Two prominent buttons for "Schedule New Run" and "View Scheduled Runs"
- **RunSummaryCard**: Reusable card component showing run overview (day, time, stops count)
- **EmptyStateView**: Displayed when no runs exist in upcoming or past sections

**State Management**:
```swift
@StateObject private var runManager = SchoolRunManager()
@State private var showingScheduleView = false
@State private var showingListView = false
```

### 2. ScheduleNewRunView

**Purpose**: Form-based interface for creating new school runs with multiple stops

**Layout Structure**:
```swift
NavigationView {
    Form {
        Section("Run Details") {
            TextField("Run Name", text: $runName)
            DatePicker("Day", selection: $selectedDate, displayedComponents: .date)
            DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
        }
        
        Section("Stops") {
            ForEach(stops.indices, id: \.self) { index in
                StopConfigurationRow(
                    stop: $stops[index],
                    children: availableChildren,
                    onDelete: { deleteStop(at: index) }
                )
            }
            
            Button("➕ Add Stop") {
                addNewStop()
            }
        }
        
        Section {
            Button("💾 Save Run") {
                saveRun()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
    .navigationTitle("Schedule New Run")
    .navigationBarTitleDisplayMode(.inline)
}
```

**Key Components**:
- **StopConfigurationRow**: Complex component handling stop name, child assignment, task input, and time estimation
- **ChildSelectionPicker**: Dropdown picker populated with mock child profiles
- **StopPresetPicker**: Picker with preset options (Home, School, OT, Music, Custom)
- **MapPlaceholderThumbnail**: Small static map image for each stop

**State Management**:
```swift
@State private var runName = ""
@State private var selectedDate = Date()
@State private var selectedTime = Date()
@State private var stops: [RunStop] = []
@State private var availableChildren: [ChildProfile] = MockDataProvider.children
```

### 3. ScheduledRunsListView

**Purpose**: Browse interface for viewing all created runs

**Layout Structure**:
```swift
NavigationView {
    List {
        ForEach(scheduledRuns) { run in
            NavigationLink(destination: RunDetailView(run: run)) {
                RunListRowView(run: run)
            }
        }
    }
    .navigationTitle("Scheduled Runs")
    .overlay {
        if scheduledRuns.isEmpty {
            EmptyStateView(
                title: "No Scheduled Runs",
                message: "Create your first school run to get started",
                actionTitle: "Schedule Run",
                action: { showingScheduleView = true }
            )
        }
    }
}
```

**Key Components**:
- **RunListRowView**: Displays run name, day/time, and stop count in a clean row format
- **EmptyStateView**: Encourages user to create first run when list is empty

**State Management**:
```swift
@StateObject private var runManager = SchoolRunManager()
@State private var showingScheduleView = false
```

### 4. RunDetailView

**Purpose**: Detailed view of a specific run before execution

**Layout Structure**:
```swift
ScrollView {
    VStack(spacing: 20) {
        // Run overview card
        RunOverviewCard(run: run)
        
        // Stops list
        VStack(alignment: .leading, spacing: 12) {
            Text("Route Details")
                .font(.headline)
            
            ForEach(Array(run.stops.enumerated()), id: \.offset) { index, stop in
                StopDetailRow(
                    stopNumber: index + 1,
                    totalStops: run.stops.count,
                    stop: stop
                )
            }
        }
        
        // Start run button
        Button("▶️ Start Run") {
            startRun()
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top)
    }
    .padding()
}
.navigationTitle(run.name)
.navigationBarTitleDisplayMode(.inline)
```

**Key Components**:
- **RunOverviewCard**: Summary showing day, time, total duration, and participant count
- **StopDetailRow**: Detailed stop information with location, child, task, and estimated time
- **RouteVisualization**: Optional simple visual representation of the route

**State Management**:
```swift
let run: SchoolRun
@State private var showingExecutionView = false
```

### 5. RunExecutionView

**Purpose**: Step-by-step execution interface with progress tracking

**Layout Structure**:
```swift
VStack(spacing: 0) {
    // Map placeholder (top half)
    MapPlaceholderView(currentStop: currentStop)
        .frame(height: UIScreen.main.bounds.height * 0.4)
    
    // Execution controls (bottom half)
    VStack(spacing: 20) {
        // Current stop info
        CurrentStopCard(
            stopNumber: currentStopIndex + 1,
            totalStops: run.stops.count,
            stop: currentStop
        )
        
        // Progress indicator
        ProgressIndicator(
            current: currentStopIndex + 1,
            total: run.stops.count
        )
        
        // Action buttons
        ExecutionControls(
            onComplete: completeCurrentStop,
            onPause: pauseRun,
            onCancel: cancelRun
        )
    }
    .padding()
    .background(Color(.systemBackground))
}
.navigationBarHidden(true)
```

**Key Components**:
- **MapPlaceholderView**: Large static map with current location indicator
- **CurrentStopCard**: Prominent display of current stop details and task
- **ProgressIndicator**: Visual progress bar showing completion status
- **ExecutionControls**: Three action buttons for completing, pausing, or cancelling

**State Management**:
```swift
let run: SchoolRun
@State private var currentStopIndex = 0
@State private var executionState: RunExecutionState = .active
@State private var showingCancelAlert = false
@Environment(\.dismiss) private var dismiss
```

## Data Models

### Core Data Structures

```swift
struct SchoolRun: Identifiable, Codable {
    let id = UUID()
    var name: String
    var scheduledDate: Date
    var scheduledTime: Date
    var stops: [RunStop]
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    
    var estimatedDuration: TimeInterval {
        stops.reduce(0) { $0 + $1.estimatedMinutes * 60 }
    }
    
    var participatingChildren: [ChildProfile] {
        stops.compactMap(\.assignedChild).uniqued()
    }
}

struct RunStop: Identifiable, Codable {
    let id = UUID()
    var name: String
    var type: StopType
    var assignedChild: ChildProfile?
    var task: String
    var estimatedMinutes: Int
    var isCompleted: Bool = false
    
    enum StopType: String, CaseIterable, Codable {
        case home = "Home"
        case school = "School"
        case ot = "OT"
        case music = "Music"
        case custom = "Custom"
        
        var icon: String {
            switch self {
            case .home: return "🏠"
            case .school: return "🏫"
            case .ot: return "🏥"
            case .music: return "🎵"
            case .custom: return "📍"
            }
        }
    }
}

struct ChildProfile: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var avatar: String
    var age: Int
}

enum RunExecutionState {
    case notStarted
    case active
    case paused
    case completed
    case cancelled
}
```

### Mock Data Provider

```swift
class MockDataProvider {
    static let children: [ChildProfile] = [
        ChildProfile(name: "Emma", avatar: "person.circle.fill", age: 8),
        ChildProfile(name: "Liam", avatar: "person.circle.fill", age: 10),
        ChildProfile(name: "Sophia", avatar: "person.circle.fill", age: 6)
    ]
    
    static let sampleRuns: [SchoolRun] = [
        SchoolRun(
            name: "Thursday School Run",
            scheduledDate: Date().addingTimeInterval(86400),
            scheduledTime: Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date()) ?? Date(),
            stops: [
                RunStop(name: "Home", type: .home, task: "Pick snacks & guitar", estimatedMinutes: 5),
                RunStop(name: "School", type: .school, assignedChild: children[0], task: "Pick up Emma", estimatedMinutes: 10),
                RunStop(name: "OT Clinic", type: .ot, assignedChild: children[0], task: "Drop Emma for therapy", estimatedMinutes: 15),
                RunStop(name: "Music School", type: .music, assignedChild: children[1], task: "Pick up Liam", estimatedMinutes: 10),
                RunStop(name: "OT Clinic", type: .ot, assignedChild: children[0], task: "Pick up Emma", estimatedMinutes: 15),
                RunStop(name: "Home", type: .home, task: "Return home", estimatedMinutes: 10)
            ]
        )
    ]
    
    static let mapPlaceholders: [String] = [
        "map-placeholder-1",
        "map-placeholder-2",
        "map-placeholder-3"
    ]
}
```

## Error Handling

### User Experience Error Handling

Since this is a UX-focused implementation, error handling focuses on user interaction feedback and form validation:

**Form Validation**:
```swift
struct RunValidation {
    static func validateRun(_ run: SchoolRun) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if run.name.isEmpty {
            errors.append(.emptyRunName)
        }
        
        if run.stops.isEmpty {
            errors.append(.noStops)
        }
        
        if run.stops.contains(where: { $0.estimatedMinutes <= 0 }) {
            errors.append(.invalidStopDuration)
        }
        
        return errors
    }
}

enum ValidationError: LocalizedError {
    case emptyRunName
    case noStops
    case invalidStopDuration
    
    var errorDescription: String? {
        switch self {
        case .emptyRunName:
            return "Please enter a name for your run"
        case .noStops:
            return "Please add at least one stop"
        case .invalidStopDuration:
            return "All stops must have a valid duration"
        }
    }
}
```

**Toast Notification System**:
```swift
class ToastNotificationManager: ObservableObject {
    @Published var currentToast: ToastMessage?
    
    func show(_ message: String, type: ToastType = .info) {
        currentToast = ToastMessage(text: message, type: type)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.currentToast = nil
        }
    }
}

struct ToastMessage {
    let text: String
    let type: ToastType
    
    enum ToastType {
        case success, info, warning, error
        
        var color: Color {
            switch self {
            case .success: return .green
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
}
```

## Testing Strategy

### Unit Testing Approach

**Model Testing**:
```swift
class SchoolRunTests: XCTestCase {
    func testRunDurationCalculation() {
        let run = SchoolRun(
            name: "Test Run",
            scheduledDate: Date(),
            scheduledTime: Date(),
            stops: [
                RunStop(name: "Stop 1", type: .home, task: "Task 1", estimatedMinutes: 10),
                RunStop(name: "Stop 2", type: .school, task: "Task 2", estimatedMinutes: 15)
            ]
        )
        
        XCTAssertEqual(run.estimatedDuration, 1500) // 25 minutes in seconds
    }
    
    func testParticipatingChildren() {
        // Test unique child extraction from stops
    }
}
```

**View Testing**:
```swift
class SchoolRunViewTests: XCTestCase {
    func testDashboardInitialState() {
        // Test dashboard renders correctly with mock data
    }
    
    func testScheduleFormValidation() {
        // Test form validation logic
    }
    
    func testExecutionStateTransitions() {
        // Test run execution state changes
    }
}
```

**Integration Testing**:
```swift
class SchoolRunIntegrationTests: XCTestCase {
    func testCompleteRunCreationFlow() {
        // Test full flow from dashboard to run creation
    }
    
    func testRunExecutionFlow() {
        // Test complete execution from start to finish
    }
}
```

### Manual Testing Scenarios

**Navigation Flow Testing**:
1. Navigate from main app to School Run Dashboard
2. Create new run through complete form flow
3. Browse scheduled runs and view details
4. Execute run step-by-step
5. Return to dashboard and verify completed run

**Form Interaction Testing**:
1. Test all form inputs and validation
2. Add/remove stops dynamically
3. Test drag-and-drop stop reordering
4. Verify child assignment dropdowns
5. Test save functionality

**Execution Mode Testing**:
1. Start run execution and verify initial state
2. Complete stops sequentially
3. Test pause/resume functionality
4. Test cancellation with confirmation
5. Verify progress tracking accuracy

**Accessibility Testing**:
1. Navigate entire flow with VoiceOver
2. Test with large text sizes
3. Verify high contrast mode compatibility
4. Test keyboard navigation where applicable

### Performance Considerations

**Memory Management**:
- Use `@StateObject` for managers that persist across view lifecycle
- Use `@State` for local view state that doesn't need persistence
- Implement proper cleanup in execution mode to prevent memory leaks

**UI Performance**:
- Use `LazyVStack` for large lists of runs or stops
- Implement efficient list updates with proper `id` values
- Use placeholder images that load quickly
- Minimize state updates during execution mode

**Data Persistence**:
- Store runs in UserDefaults for demo purposes
- Implement simple JSON encoding/decoding for run data
- Clear old completed runs to prevent storage bloat
- Use efficient data structures for quick lookups