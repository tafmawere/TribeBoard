# Design Document

## Overview

This design addresses the compilation errors in the TribeBoard iOS app by systematically fixing SwiftUI expression complexity issues, correcting component parameter mismatches, resolving type conflicts, and ensuring proper API usage across all affected files.

## Architecture

The fix strategy follows a layered approach:

1. **Expression Simplification Layer**: Break down complex SwiftUI expressions into smaller, manageable components
2. **Type Consistency Layer**: Ensure all type usage is consistent and properly converted where needed
3. **Component Interface Layer**: Correct all component calls to match their expected signatures
4. **Validation Layer**: Verify all fixes maintain functionality while resolving compilation issues

## Components and Interfaces

### SwiftUI Expression Simplification

**Affected Files:**
- `FamilyDashboardView.swift` - Complex body expression causing compiler timeout
- `MainNavigationView.swift` - Complex body expression causing compiler timeout

**Strategy:**
- Extract complex view hierarchies into separate computed properties or private methods
- Use `@ViewBuilder` functions to break down large view compositions
- Implement conditional view rendering using separate view components

### Component Parameter Corrections

**AccessibleButton Usage:**
- Current signature: `init(action:label:hint:isEnabled:isLoading:loadingText:content:)`
- Missing `content` parameter in multiple call sites
- Incorrect haptic style enum usage

**Affected Files:**
- `MockOnboardingView.swift`
- `OnboardingView.swift`

### Type Mismatch Resolutions

**MockFamilyDashboardView Issues:**
- `MemberRowView` parameter mismatch: expects `InMemoryMember` but receives `Membership`
- `userProfile` parameter type conversion: `UserProfile?` to `InMemoryUser?`
- Argument label correction: `userProfile:` should be `user:`

## Data Models

### Type Mapping Strategy

```swift
// Current problematic usage
MemberRowView(
    member: member,                    // Membership -> InMemoryMember
    userProfile: viewModel.userProfile(for: member), // UserProfile? -> InMemoryUser?
    canManage: canManage,
    onRoleChange: onRoleChange,
    onRemove: onRemove
)

// Corrected usage
MemberRowView(
    member: convertToInMemoryMember(member),
    user: convertToInMemoryUser(viewModel.userProfile(for: member)),
    canManage: canManage,
    onRoleChange: onRoleChange,
    onRemove: onRemove
)
```

### Conversion Functions

Implement helper functions to convert between incompatible types:
- `Membership` to `InMemoryMember` conversion
- `UserProfile` to `InMemoryUser` conversion

## Error Handling

### Compilation Error Categories

1. **Type-checking timeout errors**: Resolve by expression simplification
2. **Parameter mismatch errors**: Fix by correcting argument labels and types
3. **Missing parameter errors**: Add required parameters with appropriate default values
4. **Type inference errors**: Provide explicit type annotations where needed

### Fallback Strategies

- Use explicit type annotations when compiler inference fails
- Implement default parameter values for optional components
- Add type conversion utilities for incompatible but related types

## Testing Strategy

### Compilation Verification

1. **Build Test**: Ensure `xcodebuild` completes without errors
2. **Incremental Testing**: Fix one file at a time and verify compilation
3. **Regression Testing**: Ensure fixes don't break existing functionality

### Component Testing

1. **AccessibleButton**: Verify all call sites provide required parameters
2. **MemberRowView**: Test type conversions work correctly
3. **SwiftUI Views**: Ensure simplified expressions render correctly

### Integration Testing

1. **View Rendering**: Verify all fixed views display properly
2. **User Interaction**: Test that button actions and haptic feedback work
3. **Navigation Flow**: Ensure view transitions remain functional

## Implementation Phases

### Phase 1: Expression Simplification
- Fix `FamilyDashboardView.swift` complex expression
- Fix `MainNavigationView.swift` complex expression

### Phase 2: Component Parameter Fixes
- Correct `AccessibleButton` usage in `MockOnboardingView.swift`
- Correct `AccessibleButton` usage in `OnboardingView.swift`
- Fix haptic style enum references

### Phase 3: Type Mismatch Resolution
- Implement type conversion functions
- Fix `MockFamilyDashboardView.swift` parameter issues
- Correct argument labels

### Phase 4: Validation and Testing
- Run full build to verify all errors are resolved
- Test affected views for proper functionality
- Ensure no regressions in user experience