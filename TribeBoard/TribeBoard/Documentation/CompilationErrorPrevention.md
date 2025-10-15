# Compilation Error Prevention Best Practices

## Overview

This document outlines best practices to prevent compilation errors similar to those fixed in the compilation-error-fixes spec. These guidelines help maintain clean, unambiguous code that compiles reliably.

## Type Naming Conventions

### 1. Mock vs Production Types

**Problem**: Type ambiguity between mock data structures and production models.

**Solution**: Use clear prefixes for mock/prototype types:

```swift
// ✅ Good - Clear separation
struct MockCalendarEvent { ... }        // For demos/previews
@Model class CalendarEvent { ... }      // Production SwiftData model

// ❌ Bad - Ambiguous
struct CalendarEvent { ... }            // Conflicts with SwiftData model
```

**Naming Conventions**:
- Mock types: `Mock*`, `Demo*`, `Prototype*`
- Test types: `Test*`, `Stub*`, `Fake*`
- Production types: No prefix (clean names)

### 2. Enum Case Consistency

**Problem**: References to non-existent enum cases.

**Solution**: Always verify enum cases exist before using them:

```swift
// ✅ Good - Use existing cases
CalendarPermissionType.deleteFamilyEvents
CalendarPermissionType.deleteOwnEvents

// ❌ Bad - Non-existent case
CalendarPermissionType.deleteEvents
```

**Best Practices**:
- Use Xcode autocomplete to verify enum cases
- Add unit tests for enum case coverage
- Document enum cases when they have specific meanings

## Method Signature Best Practices

### 1. Parameter Labels

**Problem**: Missing or incorrect parameter labels in method calls.

**Solution**: Always use proper parameter labels:

```swift
// ✅ Good - Correct parameter labels
CalendarErrorLogger.shared.logError(error, context: context)

// ❌ Bad - Missing parameter labels
CalendarErrorLogger.shared.logError(error, context)
```

**Guidelines**:
- Use Xcode autocomplete for method signatures
- Add parameter labels for clarity even when optional
- Document method signatures when they're complex

### 2. Method Existence Verification

**Problem**: Calling methods that don't exist.

**Solution**: Verify method names before calling:

```swift
// ✅ Good - Existing method
eventKitManager.setupTribeBoardCalendars()

// ❌ Bad - Non-existent method
eventKitManager.setupAllTribeBoardCalendars()
```

## Struct and Class Definition Best Practices

### 1. Complete Type Definitions

**Problem**: Incomplete struct definitions with missing braces or properties.

**Solution**: Always complete type definitions properly:

```swift
// ✅ Good - Complete struct definition
struct SyncStatusInfo {
    let isOnline: Bool
    let isSyncing: Bool
    let syncProgress: Double
    let lastSyncDate: Date?
    let pendingOperations: Int
    let offlineStatistics: OfflineStatistics
    let syncError: String?
    
    // Computed properties and methods...
}

// ❌ Bad - Incomplete definition
struct SyncStatusInfo {
    let isOnline: Bool
    let isSyncing: Bool
    // Missing closing brace and other properties
```

### 2. Explicit Type Annotations

**Problem**: Compiler cannot infer types in complex expressions.

**Solution**: Add explicit type annotations where beneficial:

```swift
// ✅ Good - Explicit type annotation for clarity
return events.compactMap { (event: CalendarEvent) -> CalendarEvent? in
    // Complex transformation logic
    return transformedEvent
}

// ✅ Also good - Simple cases can omit annotations
return events.compactMap { $0.isValid ? $0 : nil }
```

## File Organization Best Practices

### 1. Import Management

**Problem**: Conflicting imports causing type ambiguity.

**Solution**: Organize imports clearly and use specific imports when needed:

```swift
// ✅ Good - Clear imports
import Foundation
import SwiftData
import EventKit

// If needed, use specific imports to avoid conflicts
import struct MyFramework.CalendarEvent as FrameworkCalendarEvent
```

### 2. File Structure

**Problem**: Orphaned code and syntax errors.

**Solution**: Maintain clean file structure:

```swift
// ✅ Good - Clean file structure
import statements
// MARK: - Type Definitions
// MARK: - Extensions
// MARK: - Preview Helpers (if applicable)
// End of file - no orphaned code
```

## Code Review Checklist

### Before Committing Code

- [ ] All types have unique, descriptive names
- [ ] No type name conflicts between mock and production code
- [ ] All method calls use correct signatures and parameter labels
- [ ] All enum references use existing cases
- [ ] All struct/class definitions are complete
- [ ] No orphaned code or syntax errors
- [ ] Imports are clean and necessary
- [ ] Complex closures have explicit type annotations where helpful

### During Code Review

- [ ] Check for type naming conflicts
- [ ] Verify method signatures match implementations
- [ ] Ensure enum cases exist
- [ ] Look for incomplete type definitions
- [ ] Check file structure and syntax

## Testing Strategies

### 1. Compilation Tests

Add build verification to your CI/CD pipeline:

```bash
# Verify project compiles without errors
xcodebuild -project TribeBoard.xcodeproj -scheme TribeBoard -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### 2. Type Resolution Tests

Create unit tests that verify type resolution:

```swift
func testTypeResolution() {
    // Verify production types are accessible
    let event = CalendarEvent(...)
    XCTAssertNotNil(event)
    
    // Verify mock types are separate
    let mockEvent = MockCalendarEvent(...)
    XCTAssertNotNil(mockEvent)
}
```

## Tools and Automation

### 1. Xcode Settings

Configure Xcode to catch issues early:
- Enable "Treat Warnings as Errors" for critical targets
- Use strict Swift settings
- Enable all relevant warnings

### 2. SwiftLint Rules

Add SwiftLint rules to catch naming issues:

```yaml
# .swiftlint.yml
type_name:
  min_length: 3
  max_length: 40
  excluded:
    - ID
    - URL

identifier_name:
  min_length: 1
  max_length: 40
```

### 3. Pre-commit Hooks

Set up pre-commit hooks to verify compilation:

```bash
#!/bin/sh
# Pre-commit hook to verify compilation
xcodebuild -project TribeBoard.xcodeproj -scheme TribeBoard -destination 'platform=iOS Simulator,name=iPhone 15' build -quiet
```

## Conclusion

Following these best practices will help prevent the types of compilation errors that were fixed in the compilation-error-fixes spec. The key principles are:

1. **Clear Naming**: Use descriptive, unambiguous names for all types
2. **Complete Definitions**: Always finish what you start
3. **Explicit Signatures**: Use proper method signatures and parameter labels
4. **Consistent Structure**: Maintain clean, organized code files
5. **Regular Verification**: Test compilation frequently during development

By following these guidelines, you can maintain a robust, error-free codebase that compiles reliably and is easy to maintain.