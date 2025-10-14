# Design Document

## Overview

The SampleFamilyDataGenerator compilation errors stem from three main issues:
1. Type conversion mismatches between SampleDataError and FamilyCreationError
2. Main actor isolation violations when calling DataService methods
3. Incomplete switch statement coverage

The design will address these issues by implementing proper error conversion mechanisms, adding async/await context handling, and ensuring exhaustive switch coverage.

## Architecture

### Error Handling Strategy

The current architecture has two separate error types:
- `SampleDataError`: Specific to sample data generation operations
- `FamilyCreationError`: General family creation errors used by DataService

**Design Decision**: Maintain both error types but implement proper conversion mechanisms where needed. This preserves the specific error context while ensuring compatibility with existing systems.

### Actor Isolation Strategy

The DataService methods are marked as `@MainActor` isolated, but the SampleFamilyDataGenerator calls them from non-main actor contexts.

**Design Decision**: Modify the calling methods to be async and ensure proper actor context when calling DataService methods.

## Components and Interfaces

### Error Conversion Component

```swift
// Extension to SampleDataError for FamilyCreationError conversion
extension SampleDataError {
    func toFamilyCreationError() -> FamilyCreationError {
        // Convert SampleDataError cases to appropriate FamilyCreationError cases
    }
}
```

### Async Context Handling

```swift
// Methods that call DataService will be modified to:
// 1. Be marked as async
// 2. Use await when calling DataService methods
// 3. Handle main actor isolation properly
```

### Switch Statement Completion

```swift
// Add missing cases to switch statements
// Ensure all enum cases are handled
// Add default cases where appropriate
```

## Data Models

No new data models are required. The existing error types will be enhanced with conversion capabilities.

## Error Handling

### Error Conversion Mapping

| SampleDataError | FamilyCreationError |
|-----------------|-------------------|
| `.familyAlreadyExists` | `.familyAlreadyExists` |
| `.codeGenerationFailed` | `.codeGenerationFailed` |
| `.memberCreationFailed` | `.validationFailed` |
| `.validationFailed` | `.validationFailed` |
| `.dataServiceUnavailable` | `.unknownError` |
| `.databaseError` | `.unknownError` |
| `.networkError` | `.networkUnavailable` |
| `.unknownError` | `.unknownError` |

### Actor Isolation Fixes

1. Mark methods that call DataService as `async`
2. Use `await` when calling main actor isolated methods
3. Ensure proper error propagation in async contexts

## Testing Strategy

### Unit Testing
- Test error conversion methods
- Verify async/await behavior
- Test switch statement coverage

### Integration Testing
- Test SampleFamilyDataGenerator with real DataService
- Verify error handling flows
- Test actor isolation behavior

### Error Scenario Testing
- Test all error conversion paths
- Verify error context preservation
- Test async error propagation