# Design Document

## Overview

This feature will create a sample data generation system that populates the database with 5 realistic families for testing the "join existing family" functionality. The system will leverage existing models (Family, UserProfile, Membership) and services (DataService, FamilyCodeGenerator) to create consistent, valid test data.

## Architecture

The sample data generation will be implemented as a utility class that can be called from the app's development/demo environment. It will use the existing DataService for all database operations to ensure consistency with the app's data layer patterns.

### Key Components

1. **SampleFamilyDataGenerator**: Main utility class for generating sample families
2. **SampleFamilyData**: Data structure containing predefined family information
3. **Integration with existing DataService**: Uses established patterns for data creation
4. **Console output system**: Provides family codes for easy testing access

## Components and Interfaces

### SampleFamilyDataGenerator

```swift
class SampleFamilyDataGenerator {
    private let dataService: DataService
    
    init(dataService: DataService)
    
    // Main generation method
    func generateSampleFamilies() async throws -> [GeneratedFamilyInfo]
    
    // Helper methods
    private func createSampleFamily(data: SampleFamilyData) async throws -> GeneratedFamilyInfo
    private func createSampleUsers(for familyData: SampleFamilyData) async throws -> [UserProfile]
    private func createMemberships(family: Family, users: [UserProfile], roles: [Role]) async throws
    private func checkExistingFamilies() async throws -> [String]
    private func outputFamilyCodes(_ families: [GeneratedFamilyInfo])
}
```

### SampleFamilyData Structure

```swift
struct SampleFamilyData {
    let name: String
    let members: [SampleMemberData]
}

struct SampleMemberData {
    let displayName: String
    let role: Role
    let appleUserIdHash: String // Generated unique hash for testing
}

struct GeneratedFamilyInfo {
    let family: Family
    let code: String
    let memberCount: Int
}
```

### Integration Points

- **DataService**: All database operations will use existing DataService methods
- **FamilyCodeGenerator**: Will use existing code generation for unique family codes
- **Existing Models**: Family, UserProfile, Membership models remain unchanged
- **Error Handling**: Uses existing DataServiceError patterns

## Data Models

### Sample Family Definitions

The system will create 5 predefined families with realistic data:

1. **The Johnson Family**
   - Admin: Sarah Johnson (parent_admin)
   - Members: Mike Johnson (adult), Emma Johnson (kid), Jake Johnson (kid)

2. **The Garcia Household**
   - Admin: Carlos Garcia (parent_admin)
   - Members: Maria Garcia (adult), Sofia Garcia (kid)

3. **The Chen Family**
   - Admin: Li Chen (parent_admin)
   - Members: Wei Chen (adult), Amy Chen (kid), David Chen (kid), Grace Chen (kid)

4. **The Williams Home**
   - Admin: Jennifer Williams (parent_admin)
   - Members: Robert Williams (adult), Tyler Williams (kid)

5. **The Anderson Family**
   - Admin: Mark Anderson (parent_admin)
   - Members: Lisa Anderson (adult), Chloe Anderson (kid), Noah Anderson (kid)

### Data Validation

Each generated family will include:
- Valid family name (2-50 characters)
- Unique 6-character family code
- At least one parent_admin member
- 2-4 total members per family
- Realistic member names and roles
- Proper relationship setup between Family, UserProfile, and Membership

## Error Handling

### Idempotency Strategy

The system will check for existing sample families before creation:
1. Query existing families by name patterns
2. Skip creation if sample families already exist
3. Output existing family codes if found
4. Provide clear feedback about what was created vs. skipped

### Error Recovery

- **Database Errors**: Use DataService's existing transaction safety
- **Validation Errors**: Validate all data before insertion
- **Code Conflicts**: Regenerate codes if conflicts occur
- **Partial Failures**: Clean up partially created data on errors

### Error Types

```swift
enum SampleDataError: LocalizedError {
    case familyAlreadyExists(String)
    case codeGenerationFailed
    case memberCreationFailed(String)
    case partialCreationFailure([String])
    
    var errorDescription: String? { ... }
}
```

## Testing Strategy

### Unit Testing Approach

1. **Data Generation Tests**
   - Verify correct number of families created
   - Validate family data structure and relationships
   - Test idempotency behavior

2. **Integration Tests**
   - Test with real DataService instance
   - Verify database persistence
   - Test family code uniqueness

3. **Error Handling Tests**
   - Test behavior when families already exist
   - Test database error scenarios
   - Test partial failure recovery

### Manual Testing

1. **Console Output Verification**
   - Verify all 5 family codes are displayed
   - Test codes work with join family flow
   - Verify family names and member counts

2. **Join Family Testing**
   - Use generated codes to test join family functionality
   - Verify different role scenarios
   - Test with different user accounts

## Implementation Considerations

### Performance

- Generate all families in a single transaction when possible
- Use batch operations for member creation
- Minimize database round trips

### Security

- Generate realistic but fake Apple ID hashes for testing
- Ensure no real user data is used
- Clear separation between sample and production data

### Maintainability

- Configurable family data through static definitions
- Easy to modify sample family compositions
- Clear logging for debugging

### Development Workflow Integration

The sample data generator will be accessible through:
1. Demo/development menu in the app
2. Xcode debug console commands
3. Potential integration with existing demo utilities

This design leverages the existing TribeBoard architecture while providing a robust, testable solution for generating sample family data that supports the join family testing workflow.