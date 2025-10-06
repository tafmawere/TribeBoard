# Design Document

## Overview

This design document outlines the implementation of family creation and role assignment functionality for the TribeBoard app. The solution will enhance existing UI components by adding in-memory data management logic without requiring database, CloudKit, or backend services. The implementation focuses on connecting business logic to existing views while maintaining the current UI/UX design.

## Architecture

### High-Level Architecture

The implementation follows the existing MVVM (Model-View-ViewModel) pattern used throughout the TribeBoard app:

```
Views (Existing UI) ↔ ViewModels (Enhanced) ↔ In-Memory Data Manager ↔ Data Models (Simplified)
```

### Key Components

1. **In-Memory Data Manager**: Central storage for family and user data during app session
2. **Simplified Data Models**: Lightweight versions of existing models for in-memory storage
3. **Enhanced ViewModels**: Updated existing ViewModels to work with in-memory data
4. **Family Code Generator**: Utility for generating unique alphanumeric family codes

## Components and Interfaces

### 1. In-Memory Data Manager

```swift
@MainActor
class InMemoryFamilyDataManager: ObservableObject {
    @Published var families: [InMemoryFamily] = []
    @Published var users: [InMemoryUser] = []
    
    // Family operations
    func createFamily(name: String, createdByUserId: UUID) -> InMemoryFamily
    func findFamily(byCode: String) -> InMemoryFamily?
    func addMemberToFamily(familyId: UUID, user: InMemoryUser, role: Role) -> Bool
    
    // User operations
    func createUser(name: String) -> InMemoryUser
    func updateUserRole(userId: UUID, familyId: UUID, newRole: Role) -> Bool
}
```

### 2. Simplified Data Models

#### InMemoryFamily
```swift
struct InMemoryFamily: Identifiable, Codable {
    let id: UUID
    var name: String
    let code: String
    var members: [InMemoryMember]
    let createdAt: Date
    
    init(name: String, code: String)
}
```

#### InMemoryUser
```swift
struct InMemoryUser: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date
    
    init(name: String)
}
```

#### InMemoryMember
```swift
struct InMemoryMember: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let familyId: UUID
    var role: Role
    let joinedAt: Date
    
    init(userId: UUID, familyId: UUID, role: Role)
}
```

#### Role Enum (Simplified)
```swift
enum Role: String, CaseIterable, Codable {
    case parent = "Parent"
    case child = "Child"
    case guardian = "Guardian"
    case helper = "Helper"
    
    var displayName: String { rawValue }
    var description: String { /* role descriptions */ }
}
```

### 3. Family Code Generator

```swift
class FamilyCodeGenerator {
    static func generateCode() -> String {
        // Generate 6-character alphanumeric code (e.g., "ABC123")
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    static func isValidCodeFormat(_ code: String) -> Bool {
        // Validate 6-character alphanumeric format
        return code.count == 6 && code.allSatisfy { $0.isLetter || $0.isNumber }
    }
}
```

### 4. Enhanced ViewModels

#### CreateFamilyViewModel (Enhanced)
- Remove CloudKit and database dependencies
- Add in-memory data manager integration
- Implement family creation with code generation
- Handle navigation to role selection

#### JoinFamilyViewModel (Enhanced)
- Remove CloudKit and database dependencies
- Add family code validation and lookup
- Implement family joining logic
- Handle navigation to role selection

#### RoleSelectionViewModel (Enhanced)
- Remove CloudKit and database dependencies
- Add role assignment logic
- Handle navigation to family dashboard

#### FamilyDashboardViewModel (Enhanced)
- Remove CloudKit and database dependencies
- Display family members from in-memory storage
- Implement member management (add member navigation)

## Data Models

### Data Flow

1. **Family Creation Flow**:
   ```
   User Input → CreateFamilyViewModel → InMemoryDataManager → InMemoryFamily Created → Navigation to Role Selection
   ```

2. **Family Joining Flow**:
   ```
   Family Code Input → JoinFamilyViewModel → InMemoryDataManager → Family Lookup → Navigation to Role Selection
   ```

3. **Role Assignment Flow**:
   ```
   Role Selection → RoleSelectionViewModel → InMemoryDataManager → Member Added to Family → Navigation to Dashboard
   ```

4. **Dashboard Display Flow**:
   ```
   Dashboard Load → FamilyDashboardViewModel → InMemoryDataManager → Display Family Members
   ```

### Data Persistence Strategy

- **Session-based Storage**: All data stored in memory only
- **App Restart Behavior**: All family data cleared on app restart
- **State Management**: Use @StateObject and ObservableObject for reactive updates
- **Data Sharing**: Single InMemoryFamilyDataManager instance shared across ViewModels

## Error Handling

### Error Types

```swift
enum FamilyCreationError: LocalizedError {
    case invalidFamilyName
    case codeGenerationFailed
    case userNotFound
    
    var errorDescription: String? { /* user-friendly messages */ }
}

enum FamilyJoinError: LocalizedError {
    case invalidCode
    case familyNotFound
    case alreadyMember
    
    var errorDescription: String? { /* user-friendly messages */ }
}
```

### Error Handling Strategy

1. **Input Validation**: Real-time validation with user feedback
2. **Toast Messages**: Success/error notifications using existing toast system
3. **Alert Dialogs**: Critical error handling with retry options
4. **Graceful Degradation**: Fallback to previous state on errors

## Testing Strategy

### Unit Testing

1. **InMemoryFamilyDataManager Tests**:
   - Family creation and retrieval
   - Member addition and role updates
   - Code generation and validation

2. **ViewModel Tests**:
   - Family creation flow
   - Family joining flow
   - Role selection flow
   - Dashboard data loading

3. **Utility Tests**:
   - Family code generation
   - Code format validation
   - Error handling scenarios

### Integration Testing

1. **End-to-End Flow Tests**:
   - Complete family creation to dashboard flow
   - Family joining and role assignment flow
   - Multiple users joining same family

2. **UI Integration Tests**:
   - ViewModel-View integration
   - Navigation flow testing
   - Error state handling

### Manual Testing Scenarios

1. **Happy Path Testing**:
   - Create family → assign role → view dashboard
   - Join family → assign role → view dashboard

2. **Error Scenarios**:
   - Invalid family codes
   - Duplicate family names
   - Network simulation (offline behavior)

3. **Edge Cases**:
   - App restart behavior
   - Multiple family creation attempts
   - Role assignment constraints

## Implementation Approach

### Phase 1: Data Layer
1. Create InMemoryFamilyDataManager
2. Implement simplified data models
3. Add family code generation utility

### Phase 2: ViewModel Enhancement
1. Update CreateFamilyViewModel for in-memory storage
2. Update JoinFamilyViewModel for code validation
3. Update RoleSelectionViewModel for role assignment
4. Update FamilyDashboardViewModel for member display

### Phase 3: Integration and Testing
1. Connect ViewModels to existing Views
2. Test complete user flows
3. Handle error scenarios
4. Validate navigation flows

### Phase 4: Polish and Optimization
1. Optimize performance for in-memory operations
2. Enhance user feedback and error messages
3. Add accessibility improvements
4. Final testing and validation

## Technical Considerations

### Memory Management
- Use weak references where appropriate to prevent retain cycles
- Implement proper cleanup in deinit methods
- Monitor memory usage during testing

### Performance
- Optimize family lookup operations
- Use lazy loading for member lists
- Implement efficient data structures for quick access

### Scalability
- Design for easy migration to persistent storage later
- Keep data models compatible with existing CloudKit models
- Maintain separation of concerns for future enhancements

### Accessibility
- Ensure all new functionality is accessible
- Add proper accessibility labels and hints
- Test with VoiceOver and other assistive technologies