# Design Document

## Overview

The School Run UI feature provides a dedicated SwiftUI screen for visualizing and managing school transportation runs within the TribeBoard family coordination app. This is a UI/UX showcase implementation that demonstrates visual design patterns, user interaction flows, and component composition without requiring backend integration. The design leverages TribeBoard's existing design system, component library, and navigation patterns to create a cohesive user experience.

The screen follows a top-to-bottom layout with a header, map visualization area, trip information card, and integrated bottom navigation. All interactions are handled through local state management with static placeholder data to showcase the intended user experience.

## Architecture

### Component Hierarchy

```
SchoolRunView (New Implementation)
├── Header Section
│   ├── Navigation Bar (Back Button + Title + Family Avatar)
├── Map Section (Top Half)
│   ├── Map Placeholder Container
│   ├── Route Overlay (Static Line)
│   └── Location Icons (Driver, School, Home)
├── Trip Information Card (Bottom Half)
│   ├── Driver Info Section
│   ├── Children Section
│   ├── Destination Info Section
│   ├── ETA Section
│   ├── Status Badge
│   └── Action Buttons Section
└── Bottom Navigation (Inherited from MainNavigationView)
```

### State Management

The component will use local `@State` variables for UI interactions:
- `isRunActive: Bool` - Toggles between "Start Run" and "End Run" states
- `showNotificationSent: Bool` - Provides feedback for "Notify Family" action
- `showSOSAlert: Bool` - Handles SOS button interactions

### Integration Points

- Inherits navigation from `MainNavigationView`
- Uses `FloatingBottomNavigation` component
- Leverages `DesignSystem` for consistent styling
- Utilizes `BrandColors` and `ButtonStyles` from existing utilities

## Components and Interfaces

### 1. Header Component

**Purpose**: Provides navigation context and family identification

**Implementation**:
```swift
NavigationView {
    // Content
    .navigationTitle("School Run")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Back") { /* Navigate to Family Dashboard */ }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            // Family avatar/logo
        }
    }
}
```

**Styling**:
- Uses standard iOS navigation bar
- Title: DesignSystem.Typography.titleLarge
- Back button: System default with brand color
- Family avatar: 32x32 circular image

### 2. Map Placeholder Component

**Purpose**: Visual representation of the school run route

**Implementation**:
```swift
ZStack {
    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
        .fill(Color.gray.opacity(0.1))
        .frame(height: 250)
        .overlay(
            Text("Map Placeholder")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(.secondary)
        )
    
    // Route line overlay
    Path { path in
        // Static route path
    }
    .stroke(Color.brandPrimary, lineWidth: 3)
    
    // Location icons
    HStack {
        LocationIcon(type: .home, icon: "🏠")
        Spacer()
        LocationIcon(type: .school, icon: "🏫")
        Spacer()
        LocationIcon(type: .driver, icon: "🚗")
    }
}
```

**Styling**:
- Container: 250pt height, rounded corners (20pt)
- Background: Gray opacity 0.1
- Route line: Brand primary color, 3pt width
- Icons: 40x40 circular backgrounds with emoji

### 3. Trip Information Card Component

**Purpose**: Displays comprehensive trip details and controls

**Implementation**:
```swift
VStack(spacing: DesignSystem.Spacing.lg) {
    // Driver Info Section
    DriverInfoSection()
    
    // Children Section  
    ChildrenSection()
    
    // Destination Info Section
    DestinationInfoSection()
    
    // ETA Section
    ETASection()
    
    // Status Badge
    StatusBadge(status: "Not Started")
    
    // Action Buttons
    ActionButtonsSection(isRunActive: $isRunActive)
}
.cardPadding()
.background(
    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
        .fill(Color(.systemBackground))
        .mediumShadow()
)
```

**Styling**:
- Card: Rounded corners (20pt), medium shadow
- Internal padding: 16pt
- Section spacing: 16pt
- Background: System background color

### 4. Action Buttons Component

**Purpose**: Primary interaction controls for the school run

**Implementation**:
```swift
VStack(spacing: DesignSystem.Spacing.md) {
    // Primary Action Button
    Button(isRunActive ? "End Run" : "Start Run") {
        isRunActive.toggle()
    }
    .buttonStyle(isRunActive ? DestructiveButtonStyle() : PrimaryButtonStyle())
    
    // Secondary Action Button
    Button("Notify Family") {
        // Handle notification
    }
    .buttonStyle(SecondaryButtonStyle())
    
    // SOS Button (Bottom-right positioned)
    HStack {
        Spacer()
        Button("SOS") {
            showSOSAlert = true
        }
        .buttonStyle(IconButtonStyle(backgroundColor: .red))
    }
}
```

**Styling**:
- Primary button: Full width, 56pt height
- Secondary button: Full width, outline style
- SOS button: 44x44 circular, red background
- Button spacing: 12pt vertical

## Data Models

### Static Data Structures

Since this is a UI-only implementation, all data will be static placeholders:

```swift
struct SchoolRunUIData {
    static let driverInfo = DriverInfo(
        name: "John Doe",
        avatar: "person.circle.fill"
    )
    
    static let children = [
        ChildInfo(name: "Emma", avatar: "person.circle"),
        ChildInfo(name: "Liam", avatar: "person.circle"),
        ChildInfo(name: "Sophia", avatar: "person.circle")
    ]
    
    static let destination = DestinationInfo(
        name: "Soccer Practice",
        time: "15:30"
    )
    
    static let eta = "15 min"
    
    static let routePoints = [
        CGPoint(x: 50, y: 100),   // Home
        CGPoint(x: 150, y: 80),   // Waypoint
        CGPoint(x: 200, y: 120)   // School
    ]
}
```

### State Models

```swift
enum RunStatus {
    case notStarted
    case inProgress
    case completed
    
    var displayText: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }
    
    var color: Color {
        switch self {
        case .notStarted: return .gray
        case .inProgress: return .brandPrimary
        case .completed: return .green
        }
    }
}
```

## Error Handling

Since this is a UI-only implementation, error handling focuses on user interaction feedback:

### User Feedback Patterns

1. **Button State Feedback**:
   - Visual state changes for button presses
   - Haptic feedback using `HapticManager`
   - Loading states for async-appearing actions

2. **Alert Presentations**:
   - SOS button triggers confirmation alert
   - Notification success feedback via toast

3. **Accessibility Support**:
   - VoiceOver labels for all interactive elements
   - Dynamic type support for text scaling
   - High contrast mode compatibility

### Implementation

```swift
.alert("Emergency Alert", isPresented: $showSOSAlert) {
    Button("Send SOS", role: .destructive) {
        // Handle SOS action
        HapticManager.shared.error()
    }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("This will send an emergency alert to all family members.")
}
```

## Testing Strategy

### Unit Testing Approach

1. **Component Rendering Tests**:
   - Verify all UI elements render correctly
   - Test different screen sizes and orientations
   - Validate accessibility properties

2. **Interaction Tests**:
   - Button tap responses
   - State transitions
   - Navigation behavior

3. **Visual Regression Tests**:
   - Screenshot comparisons
   - Dark mode compatibility
   - Dynamic type scaling

### Test Implementation

```swift
class SchoolRunViewTests: XCTestCase {
    func testInitialState() {
        // Test initial UI state
    }
    
    func testStartRunButtonToggle() {
        // Test button state changes
    }
    
    func testAccessibilityLabels() {
        // Test VoiceOver support
    }
    
    func testNavigationIntegration() {
        // Test bottom navigation integration
    }
}
```

### Manual Testing Scenarios

1. **Navigation Flow**:
   - Navigate from Family Dashboard to School Run
   - Use bottom navigation to switch between tabs
   - Return to dashboard via back button

2. **Interaction Testing**:
   - Toggle "Start Run" / "End Run" button
   - Tap "Notify Family" button
   - Trigger SOS alert

3. **Accessibility Testing**:
   - Navigate with VoiceOver enabled
   - Test with large text sizes
   - Verify high contrast mode support

4. **Visual Testing**:
   - Test on different device sizes
   - Verify dark mode appearance
   - Check landscape orientation behavior

### Performance Considerations

- Static data eliminates network latency concerns
- Minimal state management reduces complexity
- Leverages existing design system for consistency
- Uses standard SwiftUI components for optimal performance