# Design Document

## Overview

This design addresses systematic compilation errors in the TribeBoard project by implementing targeted fixes for duplicate declarations, missing enum cases, parameter mismatches, and SwiftUI syntax issues. The approach prioritizes minimal code changes while ensuring comprehensive error resolution.

## Architecture

### Error Categories
1. **Duplicate Declarations**: Remove redundant method/struct definitions
2. **Missing Enum Cases**: Add required StopType cases with proper implementations
3. **Parameter Mismatches**: Fix function calls to match expected signatures
4. **Main Actor Issues**: Resolve concurrency isolation problems
5. **SwiftUI Syntax**: Fix ViewBuilder and modifier chain issues

### Fix Strategy
- **Consolidation**: Merge duplicate functionality into single implementations
- **Extension**: Add missing enum cases with backward compatibility
- **Correction**: Fix parameter lists and function signatures
- **Isolation**: Properly handle main actor requirements
- **Validation**: Ensure SwiftUI syntax compliance

## Components and Interfaces

### 1. Accessibility Utilities Consolidation
**Purpose**: Remove duplicate accessibility method declarations
**Implementation**: 
- Identify conflicting methods in EnhancedAccessibility.swift and AccessibilityHelpers.swift
- Consolidate into single, comprehensive implementations
- Maintain existing functionality while removing duplicates

### 2. Error Handling Unification
**Purpose**: Resolve ErrorCategory redeclaration issues
**Implementation**:
- Establish single ErrorCategory definition in ErrorHandlingUtilities.swift
- Update all references to use unified error categorization
- Ensure consistent error handling across the codebase

### 3. RunStop.StopType Enhancement
**Purpose**: Add missing enum cases for school run functionality
**Implementation**:
- Add `.home`, `.school`, `.pickup`, `.dropoff` cases to StopType enum
- Implement proper display names and icons for each type
- Update initializers to handle new cases

### 4. Function Signature Corrections
**Purpose**: Fix parameter mismatches in function calls
**Implementation**:
- Analyze each compilation error for missing/extra parameters
- Update function calls to match expected signatures
- Ensure proper parameter ordering and types

### 5. Main Actor Isolation Fixes
**Purpose**: Resolve concurrency issues in ViewModels
**Implementation**:
- Add proper @MainActor annotations where needed
- Use Task.detached for non-main actor operations
- Ensure UI updates happen on main thread

### 6. SwiftUI ViewBuilder Corrections
**Purpose**: Fix ViewBuilder syntax and modifier chain issues
**Implementation**:
- Remove invalid return statements in ViewBuilder contexts
- Fix modifier chains on proper view types
- Correct preview environment configurations

### 7. SchoolRunPreviewShowcase ViewBuilder Fixes
**Purpose**: Fix ViewBuilder closure syntax errors in preview showcase
**Implementation**:
- Fix ViewBuilder closures that return function types instead of View types
- Remove extra trailing closures in function calls
- Fix environment modifiers applied to array types instead of View types
- Correct accessibility environment values to use valid enum cases

## Data Models

### Enhanced StopType Enum
```swift
enum StopType: String, CaseIterable, Codable {
    case home = "home"
    case school = "school" 
    case pickup = "pickup"
    case dropoff = "dropoff"
    case other = "other"
    
    var displayName: String { ... }
    var icon: String { ... }
}
```

### Unified ErrorCategory
```swift
enum ErrorCategory: String, CaseIterable {
    case network = "network"
    case validation = "validation"
    case persistence = "persistence"
    case authentication = "authentication"
    case unknown = "unknown"
}
```

## Error Handling

### Compilation Error Resolution Process
1. **Identification**: Categorize each error by type
2. **Analysis**: Determine root cause and impact
3. **Resolution**: Apply targeted fix with minimal changes
4. **Validation**: Ensure fix doesn't introduce new issues

### Error Prevention
- Establish clear naming conventions
- Use proper Swift concurrency patterns
- Follow SwiftUI best practices
- Implement comprehensive testing

## Testing Strategy

### Compilation Verification
- Build project after each fix category
- Verify no new errors introduced
- Test affected functionality still works

### Functionality Testing
- Run existing unit tests
- Verify UI components render correctly
- Test school run features work as expected
- Validate accessibility features function properly

### Integration Testing
- Test complete app build and launch
- Verify navigation between views
- Test data persistence and loading
- Validate error handling scenarios