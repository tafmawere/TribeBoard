# Design Document

## Overview

The floating bottom navigation feature will add a persistent, visually appealing navigation menu to the TribeBoard app's main screens. The navigation will provide quick access to four core sections: Home (Dashboard), School Run, Shopping, and Tasks. The design will integrate seamlessly with the existing UI/UX while following iOS design patterns and accessibility guidelines.

## Architecture

### Component Structure

The floating bottom navigation will be implemented as a reusable SwiftUI component that can be overlaid on existing views:

```
FloatingBottomNavigation
├── NavigationContainer (Main wrapper with floating styling)
├── NavigationItem (Individual navigation buttons)
├── NavigationState (Active state management)
└── NavigationAnimations (Transition and interaction animations)
```

### Integration Points

- **MainNavigationView**: Primary integration point for the navigation overlay
- **FamilyDashboardView**: Main screen where navigation will be most visible
- **TasksView**: Target destination for Tasks navigation
- **SchoolRunView**: Target destination for School Run navigation
- **Shopping View**: New view to be created for Shopping navigation

## Components and Interfaces

### FloatingBottomNavigation Component

```swift
struct FloatingBottomNavigation: View {
    @Binding var selectedTab: NavigationTab
    let onTabSelected: (NavigationTab) -> Void
    
    var body: some View {
        // Implementation details
    }
}
```

### NavigationTab Enum

```swift
enum NavigationTab: String, CaseIterable {
    case home = "home"
    case schoolRun = "school_run"
    case shopping = "shopping"
    case tasks = "tasks"
    
    var displayName: String { /* ... */ }
    var icon: String { /* ... */ }
    var activeIcon: String { /* ... */ }
}
```

### NavigationItem Component

```swift
struct NavigationItem: View {
    let tab: NavigationTab
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        // Individual navigation button implementation
    }
}
```

## Data Models

### Navigation State Management

The navigation state will be managed through the existing AppState class with additional properties:

```swift
extension AppState {
    @Published var selectedNavigationTab: NavigationTab = .home
    
    func selectTab(_ tab: NavigationTab) {
        selectedNavigationTab = tab
        // Handle navigation logic
    }
}
```

### Navigation Configuration

```swift
struct NavigationConfiguration {
    let tabs: [NavigationTab]
    let appearance: NavigationAppearance
    let animations: NavigationAnimations
}

struct NavigationAppearance {
    let backgroundColor: Color
    let activeColor: Color
    let inactiveColor: Color
    let shadowStyle: ShadowStyle
    let cornerRadius: CGFloat
}
```

## Visual Design Specifications

### Layout and Positioning

- **Container**: Floating 16pt from bottom safe area, 20pt from horizontal edges
- **Height**: 72pt total height (56pt content + 16pt internal padding)
- **Width**: Full width minus 40pt horizontal margins
- **Corner Radius**: 24pt (using BrandStyle.cornerRadiusLarge)

### Styling

- **Background**: Semi-transparent white with blur effect (.systemBackground with 0.95 opacity)
- **Shadow**: Medium shadow from DesignSystem.Shadow.medium
- **Border**: Subtle 1pt border with .separator color at 0.2 opacity

### Navigation Items

- **Touch Target**: 44x44pt minimum (DesignSystem.Layout.minTouchTarget)
- **Icon Size**: 24x24pt for icons
- **Spacing**: Equal distribution across container width
- **Active State**: Brand primary color with scale animation
- **Inactive State**: Secondary color with reduced opacity

### Typography

- **Labels**: DesignSystem.Typography.captionMedium (11pt, medium weight)
- **Active Labels**: Brand primary color
- **Inactive Labels**: Secondary color

## Accessibility Features

### VoiceOver Support

- Each navigation item will have descriptive accessibility labels
- Active state will be announced ("Home, selected" vs "Home, button")
- Navigation container will be treated as a tab bar landmark

### Dynamic Type Support

- Icons will scale appropriately with Dynamic Type settings
- Labels will respect user's preferred text size
- Minimum touch targets maintained at all text sizes

### High Contrast Support

- Colors will adapt to high contrast accessibility settings
- Border visibility will increase in high contrast mode
- Icon contrast will meet WCAG AA standards

## Animation and Interactions

### Tap Animations

- **Scale Animation**: 0.95 scale on press, spring back on release
- **Color Transition**: Smooth color change over 0.2 seconds
- **Icon Animation**: Active icons may include subtle bounce effect

### Tab Switching

- **Selection Indicator**: Smooth slide animation between tabs
- **Content Transition**: Coordinated with view transitions
- **Haptic Feedback**: Light impact feedback on tab selection

### Entrance/Exit Animations

- **Slide Up**: Navigation slides up from bottom on appearance
- **Fade Out**: Graceful fade when hidden (if needed)
- **Spring Animation**: Bouncy entrance for engaging feel

## Integration with Existing Navigation

### Navigation Stack Coordination

The floating navigation will work alongside the existing NavigationStack:

```swift
// In MainNavigationView
.overlay(alignment: .bottom) {
    if shouldShowBottomNavigation {
        FloatingBottomNavigation(
            selectedTab: $appState.selectedNavigationTab,
            onTabSelected: { tab in
                handleTabSelection(tab)
            }
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
```

### View Visibility Logic

- **Show On**: FamilyDashboardView, TasksView, SchoolRunView, ShoppingView
- **Hide On**: Onboarding flows, modal presentations, detail views
- **Conditional**: Based on user authentication and family membership status

## Error Handling

### Navigation Failures

- Graceful fallback if target view fails to load
- Error toast notifications for navigation issues
- Maintain current view if navigation fails

### State Synchronization

- Ensure selected tab reflects actual current view
- Handle deep linking and external navigation
- Recover from inconsistent navigation state

## Testing Strategy

### Unit Tests

- NavigationTab enum functionality
- State management in AppState extension
- Individual component rendering
- Accessibility label generation

### Integration Tests

- Navigation between different views
- State persistence across app lifecycle
- Coordination with existing navigation stack
- Animation completion and timing

### UI Tests

- Tap interactions on all navigation items
- Visual appearance across different devices
- Accessibility navigation with VoiceOver
- Performance with rapid tab switching

### Accessibility Tests

- VoiceOver navigation flow
- Dynamic Type scaling
- High contrast mode appearance
- Minimum touch target compliance

## Performance Considerations

### Rendering Optimization

- Lazy loading of destination views
- Efficient state updates to prevent unnecessary re-renders
- Optimized animation performance

### Memory Management

- Proper cleanup of view controllers
- Efficient image asset loading for icons
- Minimal impact on app launch time

## Implementation Phases

### Phase 1: Core Component
- Create FloatingBottomNavigation component
- Implement basic styling and layout
- Add to FamilyDashboardView

### Phase 2: Navigation Logic
- Integrate with AppState for navigation
- Add animation and interaction effects
- Implement accessibility features

### Phase 3: Full Integration
- Add to all target views
- Create Shopping view placeholder
- Comprehensive testing and refinement

### Phase 4: Polish and Optimization
- Performance optimization
- Advanced animations
- Edge case handling