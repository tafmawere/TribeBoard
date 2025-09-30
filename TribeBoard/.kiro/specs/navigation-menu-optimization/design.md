# Design Document

## Overview

The navigation menu optimization involves removing the messages tab from the main navigation and ensuring proper iconography for the homelife tab. This change will reduce the navigation from 6 tabs to 5 tabs, creating a cleaner and more focused user experience while maintaining all essential functionality.

## Architecture

### Current Navigation Structure
- Dashboard (house/house.fill)
- Calendar (calendar)
- School Run (car/car.fill) 
- HomeLife (house.heart/house.heart.fill)
- Tasks (checkmark.circle)
- Messages (message/message.fill) ← **TO BE REMOVED**

### Updated Navigation Structure
- Dashboard (house/house.fill)
- Calendar (calendar)
- School Run (car/car.fill)
- HomeLife (house.heart/house.heart.fill) ← **ICON CONFIRMED**
- Tasks (checkmark.circle)

## Components and Interfaces

### NavigationTab Enum
The `NavigationTab` enum in `TribeBoard/Models/NavigationTab.swift` needs to be updated to:
- Remove the `.messages` case from the enum
- Remove messages from `CaseIterable` 
- Remove messages-related display names, icons, and activeIcons
- Maintain all other tab definitions unchanged

### FloatingBottomNavigation Component
The `FloatingBottomNavigation` component will automatically adapt to the reduced number of tabs since it uses `NavigationTab.allCases`. No direct changes needed to this component.

### NavigationItem Component
The `NavigationItem` component will continue to work with the updated enum without modifications, as it dynamically uses the tab's icon properties.

### MainNavigationView
The `MainNavigationView` needs updates to:
- Remove messages-related view handling in `dashboardContent`
- Remove messages case from `destinationView(for:)` method
- Remove `MessagesPlaceholderView` references
- Ensure proper default tab selection when messages was previously selected

## Data Models

### NavigationTab Model Changes
```swift
enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard = "dashboard"
    case calendar = "calendar" 
    case schoolRun = "schoolRun"
    case homeLife = "homeLife"  // Icon already properly defined
    case tasks = "tasks"
    // case messages = "messages" ← REMOVE THIS LINE
}
```

The homelife tab already has proper icons defined:
- Inactive: "house.heart"
- Active: "house.heart.fill"

## Error Handling

### Navigation State Management
- If the current selected tab is messages when the update occurs, the system should default to the dashboard tab
- The app state should handle the transition gracefully without crashes
- Any deep links or saved state referencing messages should fallback to dashboard

### Accessibility Considerations
- Screen readers should announce the updated navigation structure
- Tab order and focus management should remain intact
- Touch targets should maintain proper spacing with 5 tabs instead of 6

## Testing Strategy

### Unit Tests
- Test NavigationTab enum has correct number of cases (5 instead of 6)
- Test that messages case is not present in allCases
- Test homelife tab has correct icon properties
- Test navigation state transitions when messages tab is removed

### Integration Tests
- Test FloatingBottomNavigation renders 5 tabs correctly
- Test tab selection works for all remaining tabs
- Test navigation flows work without messages references
- Test accessibility features work with updated navigation

### UI Tests
- Test navigation layout with 5 tabs displays correctly
- Test homelife icon displays properly in both states
- Test touch targets are appropriately sized and spaced
- Test navigation works across different device sizes

### Accessibility Tests
- Test screen reader announces correct number of navigation items
- Test tab navigation works with assistive technologies
- Test high contrast mode works with updated navigation
- Test dynamic type scaling works with 5-tab layout