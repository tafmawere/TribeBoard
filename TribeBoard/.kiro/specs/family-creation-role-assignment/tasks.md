# Implementation Plan

- [x] 1. Create simplified SwiftUI data models for in-memory storage
  - Create InMemoryFamily struct conforming to Identifiable and ObservableObject for SwiftUI binding
  - Create InMemoryUser struct with id, name, and createdAt properties conforming to Identifiable
  - Create InMemoryMember struct with userId, familyId, role, and joinedAt properties conforming to Identifiable
  - Create simplified Role enum with Parent, Child, Guardian, Helper cases for SwiftUI picker compatibility
  - _Requirements: 1.1, 5.1, 5.4_

- [x] 2. Implement family code generation utility
  - Create FamilyCodeGenerator class with generateCode() method that produces 6-character alphanumeric codes
  - Add isValidCodeFormat() method to validate code format
  - Write unit tests for code generation and validation
  - _Requirements: 1.2, 2.4_

- [x] 3. Create SwiftUI-compatible InMemoryFamilyDataManager for centralized data storage
  - Implement @MainActor ObservableObject class with @Published properties for reactive SwiftUI updates
  - Add createFamily() method that generates unique family with code and triggers SwiftUI view updates
  - Add findFamily(byCode:) method for family lookup with SwiftUI state management
  - Add addMemberToFamily() method for adding users to families with @Published property updates
  - Add createUser() and updateUserRole() methods with SwiftUI-compatible state management
  - _Requirements: 1.1, 1.2, 2.1, 3.2, 4.2, 5.1, 5.3_

- [x] 4. Enhance CreateFamilyViewModel for SwiftUI in-memory storage
  - Replace CloudKit and database dependencies with SwiftUI-compatible InMemoryFamilyDataManager
  - Update createFamily() method to use @Published properties for SwiftUI reactive updates
  - Modify family creation flow to trigger SwiftUI navigation using @EnvironmentObject AppState
  - Update error handling with @Published error states for SwiftUI alert and toast integration
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 5. Enhance JoinFamilyViewModel for SwiftUI code validation and lookup
  - Replace CloudKit and database dependencies with SwiftUI-compatible InMemoryFamilyDataManager
  - Update searchFamily() method with @Published loading states for SwiftUI progress indicators
  - Implement family code validation with real-time SwiftUI binding feedback
  - Update error handling with @Published error states for SwiftUI alert and toast notifications
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 6. Enhance RoleSelectionViewModel for SwiftUI role assignment
  - Replace CloudKit and database dependencies with SwiftUI-compatible InMemoryFamilyDataManager
  - Update setRole() and updateRole() methods with @Published selectedRole for SwiftUI binding
  - Implement role assignment logic with @Published loading states for SwiftUI progress indicators
  - Update navigation using SwiftUI @EnvironmentObject AppState for programmatic navigation
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 7. Enhance FamilyDashboardViewModel for SwiftUI member display
  - Replace CloudKit and database dependencies with SwiftUI-compatible InMemoryFamilyDataManager
  - Update loadMembers() method with @Published members array for SwiftUI List binding
  - Implement member display logic with @Published loading states for SwiftUI progress views
  - Add SwiftUI navigation using @EnvironmentObject AppState for "Add Member" flow
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 8. Update SwiftUI AppState for family and user context management
  - Add @Published currentFamily and currentUser properties for SwiftUI reactive updates
  - Implement setFamily() method that triggers SwiftUI view updates across the app
  - Add SwiftUI navigation methods using NavigationPath or programmatic navigation
  - Ensure proper SwiftUI state management with @EnvironmentObject injection
  - _Requirements: 1.5, 2.2, 3.4, 4.1_

- [x] 9. Connect enhanced ViewModels to existing SwiftUI Views
  - Update CreateFamilyView with @StateObject binding to enhanced CreateFamilyViewModel
  - Update JoinFamilyView with @StateObject binding and SwiftUI form validation
  - Update RoleSelectionView with @StateObject binding and SwiftUI selection UI
  - Update FamilyDashboardView with @StateObject binding and SwiftUI List for members
  - _Requirements: 1.1, 2.1, 3.1, 4.1_

- [x] 10. Implement SwiftUI error handling and user feedback
  - Add FamilyCreationError and FamilyJoinError enum types conforming to LocalizedError
  - Update ViewModels with @Published error states for SwiftUI alert and sheet presentation
  - Implement real-time input validation using SwiftUI @Binding and validation modifiers
  - Add SwiftUI toast notifications and success animations for user feedback
  - _Requirements: 1.1, 2.2, 2.3, 3.1, 4.1_

- [x] 11. Add SwiftUI family code display and QR code placeholder functionality
  - Update CreateFamilyView with SwiftUI conditional rendering for family code display
  - Add SwiftUI Image view with QR code placeholder (static SF Symbol or asset)
  - Implement SwiftUI copy-to-clipboard functionality with UIPasteboard integration
  - Add SwiftUI animations and visual feedback for successful family creation
  - _Requirements: 1.3, 1.4_

- [x] 12. Write comprehensive unit tests for all components
  - Create tests for InMemoryFamilyDataManager covering all CRUD operations
  - Write tests for FamilyCodeGenerator covering code generation and validation
  - Add tests for enhanced ViewModels covering all user flows
  - Create integration tests for complete family creation and joining flows
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 13. Test complete user flows and edge cases
  - Test family creation → role selection → dashboard flow
  - Test family joining → role selection → dashboard flow  
  - Test error scenarios like invalid codes and duplicate families
  - Verify app restart behavior clears all family data
  - Test multiple users joining the same family
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.2_

- [x] 14. Final SwiftUI integration and polish
  - Ensure all SwiftUI navigation flows work correctly with NavigationStack/NavigationView
  - Verify proper SwiftUI state management with @Published, @StateObject, and @EnvironmentObject
  - Test SwiftUI accessibility features and add missing accessibility modifiers
  - Optimize SwiftUI performance with proper view updates and @Published property usage
  - Add final SwiftUI error handling with alerts, sheets, and toast integration
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.1_