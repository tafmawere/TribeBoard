# Preview Environment Setup Utilities

This document describes the preview environment setup utilities implemented for consistent SwiftUI preview configuration across the TribeBoard app.

## Overview

The preview environment setup utilities ensure that all SwiftUI previews have the necessary environment objects to prevent crashes and provide consistent preview experiences.

## Components

### 1. PreviewEnvironmentModifier

A view modifier that provides consistent environment object setup for SwiftUI previews.

**Usage:**
```swift
#Preview {
    MyView()
        .previewEnvironment()
}
```

**Available Environment Types:**
- `.default` - Default preview environment with authenticated user and family
- `.unauthenticated` - Unauthenticated user state
- `.authenticated` - Authenticated user with family
- `.loading` - Loading state
- `.error` - Error state
- `.familySelection` - Family selection state
- `.parentAdmin` - Parent admin role
- `.adult` - Adult role
- `.kid` - Kid role
- `.visitor` - Visitor role

### 2. View Extensions

Convenient extension methods for easy preview environment injection:

```swift
// Basic usage
.previewEnvironment()

// Specific environment type
.previewEnvironment(.authenticated)

// Role-specific environment
.previewEnvironment(role: .parentAdmin)

// Convenience methods
.previewEnvironmentUnauthenticated()
.previewEnvironmentLoading()
.previewEnvironmentError()
.previewEnvironmentFamilySelection()

// Custom AppState
.previewEnvironment(customAppState: myCustomAppState)
```

### 3. SchoolRunPreviewProvider Updates

Enhanced preview provider with new environment setup methods:

```swift
// Updated methods
SchoolRunPreviewProvider.previewWithSampleData { MyView() }
SchoolRunPreviewProvider.previewWithEnvironment(.authenticated) { MyView() }
SchoolRunPreviewProvider.previewWithRole(.parentAdmin) { MyView() }
```

### 4. AppStateFactory Integration

The preview environment utilities integrate with the existing `AppStateFactory` to create properly configured AppState instances for different scenarios.

## Updated Views

The following views have been updated to use the new consistent preview environment setup:

- `ScheduledRunsListView`
- `MainNavigationView`
- `JoinFamilyView`
- `CreateFamilyView`
- `RunDetailView`
- `RunExecutionView`

## Benefits

1. **Crash Prevention**: All previews now have proper environment objects
2. **Consistency**: Standardized preview setup across all views
3. **Flexibility**: Easy to create previews for different user states and roles
4. **Maintainability**: Centralized preview environment configuration
5. **Testing**: Better support for testing different app states

## Example Usage

```swift
#Preview("Default State") {
    MyView()
        .previewEnvironment()
}

#Preview("Loading State") {
    MyView()
        .previewEnvironmentLoading()
}

#Preview("Parent Admin") {
    MyView()
        .previewEnvironment(role: .parentAdmin)
}

#Preview("Custom State") {
    let customAppState = AppStateFactory.createTestAppState(scenario: .familySelection)
    return MyView()
        .previewEnvironment(customAppState: customAppState)
}
```

## Validation

The `PreviewEnvironmentValidator` provides validation for preview environments to ensure they are properly configured:

```swift
let validationResult = PreviewEnvironmentValidator.validatePreviewEnvironment(appState)
if !validationResult.isValid {
    // Handle validation issues
}
```

## Testing

Comprehensive unit tests are provided in `PreviewEnvironmentTests.swift` to ensure all preview environment utilities work correctly and don't crash.