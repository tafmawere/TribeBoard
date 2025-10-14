# Implementation Plan

- [x] 1. Set up core data models and enums
  - Create SchoolRun struct with all required properties and computed values
  - Create RunStop struct with StopType enum and display formatting
  - Create RunStatus enum with display properties and color coding
  - Add Codable conformance for data persistence
  - _Requirements: 1.3, 1.4, 5.1, 5.2, 6.1, 6.2_

- [x] 2. Implement SchoolRunManager for data persistence
  - Create ObservableObject manager class with @Published properties
  - Implement CRUD operations for school runs (create, read, update, delete)
  - Add UserDefaults-based storage with JSON encoding/decoding
  - Implement run execution state management (start, pause, complete, cancel)
  - Add data validation and error handling
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 2.1 Write unit tests for SchoolRunManager
  - Test CRUD operations with mock data
  - Test data persistence and loading functionality
  - Test run execution state transitions
  - Test error handling scenarios
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 3. Create mock data generator for school runs
  - Extend MockDataGenerator with school run sample data
  - Generate diverse run scenarios (today's runs, upcoming, completed)
  - Create sample stops with different types and realistic times
  - Add edge cases for testing (empty runs, past dates, etc.)
  - _Requirements: 5.3, 5.4_

- [x] 4. Implement SchoolRunViewModel
  - Create @MainActor ObservableObject with @Published properties
  - Implement computed properties for filtering runs (today's, upcoming, completed)
  - Add methods for loading, creating, and deleting runs
  - Integrate with SchoolRunManager for data operations
  - Add error handling and loading states
  - _Requirements: 1.1, 1.2, 3.1, 3.2, 3.3_

- [x] 4.1 Write unit tests for SchoolRunViewModel
  - Test run filtering logic (today's, upcoming, completed)
  - Test CRUD operations through view model
  - Test error state management
  - Test loading state handling
  - _Requirements: 1.1, 1.2, 3.1, 3.2_

- [x] 5. Update NavigationTab enum for school run integration
  - Add schoolRun case to NavigationTab enum
  - Update displayName, icon, and activeIcon properties
  - Ensure proper integration with existing 5-tab navigation
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 6. Create main SchoolRunView
  - Implement main dashboard view with runs list
  - Add "+ New Run" button with navigation to RunPlannerView
  - Display today's runs, upcoming runs, and quick actions
  - Integrate with SchoolRunViewModel for data binding
  - Add empty state handling when no runs exist
  - Implement run card components with proper styling
  - _Requirements: 1.1, 1.2, 4.1, 4.2, 4.4, 7.1, 7.4_

- [x] 7. Implement RunPlannerViewModel
  - Create form validation logic for run creation
  - Implement stop management (add, remove, reorder)
  - Add date and time validation
  - Integrate with SchoolRunManager for saving runs
  - Handle form state and validation errors
  - _Requirements: 1.3, 1.4, 1.5, 6.3, 6.4_

- [x] 7.1 Write unit tests for RunPlannerViewModel
  - Test form validation logic
  - Test stop management operations
  - Test run creation and saving
  - Test error handling for invalid data
  - _Requirements: 1.3, 1.4, 1.5_

- [x] 8. Create RunPlannerView for scheduling new runs
  - Implement form interface with title, date, and time inputs
  - Add dynamic stops list with add/remove functionality
  - Create stop configuration UI with name, type, and time fields
  - Add form validation with inline error display
  - Implement save functionality with navigation back to main view
  - _Requirements: 1.3, 1.4, 1.5, 6.1, 6.2, 6.3, 6.4_

- [x] 9. Implement ActiveRunViewModel
  - Create view model for live run execution
  - Add current stop tracking and progress calculation
  - Implement next stop navigation and run completion logic
  - Add pause/resume functionality for runs
  - Integrate haptic feedback for user actions
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [x] 9.1 Write unit tests for ActiveRunViewModel
  - Test run execution state management
  - Test stop progression logic
  - Test progress calculation
  - Test pause/resume functionality
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 10. Create ActiveRunView for live run execution
  - Implement map placeholder view using existing MapPlaceholderView patterns
  - Display current stop information with name, type, and ETA
  - Add "Next Stop" and "End Run" action buttons
  - Show run progress indicator and remaining stops
  - Integrate haptic feedback for button interactions
  - Add pause/resume controls for run management
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 7.2, 7.3_

- [x] 11. Implement RunHistoryViewModel
  - Create view model for historical run data
  - Add filtering logic by date ranges
  - Implement run detail retrieval
  - Add search and sorting functionality
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 11.1 Write unit tests for RunHistoryViewModel
  - Test date filtering logic
  - Test run detail retrieval
  - Test search and sorting functionality
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 12. Create RunHistoryView for past runs
  - Implement list view with date-based filtering
  - Add run detail navigation and display
  - Show run summaries with stop information
  - Implement empty state for no history
  - Add search and filter controls
  - _Requirements: 3.1, 3.2, 3.3, 7.1_

- [x] 13. Create reusable UI components
  - Implement RunCard component for displaying run information
  - Create StopRow component for individual stop display
  - Build RunStatusBadge component with color coding
  - Add QuickActionButtons with consistent styling
  - Ensure all components follow existing design system patterns
  - _Requirements: 4.4, 6.2, 6.3, 7.1, 7.2, 7.4, 7.5_

- [x] 14. Integrate school run tab into main navigation
  - Update MainNavigationView to include school run tab
  - Add proper navigation routing for school run views
  - Ensure tab selection updates AppState correctly
  - Test navigation flow between all school run screens
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 15. Implement accessibility features
  - Add VoiceOver support with proper labels and hints
  - Implement Dynamic Type scaling for all text elements
  - Add high contrast color support
  - Implement reduced motion preferences
  - Add keyboard navigation support
  - Test with accessibility inspector
  - _Requirements: 4.4, 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 15.1 Write accessibility tests
  - Test VoiceOver navigation through all views
  - Test Dynamic Type scaling behavior
  - Test high contrast mode compatibility
  - Test keyboard navigation functionality
  - _Requirements: 4.4, 7.1, 7.2, 7.3_

- [x] 16. Add error handling and validation
  - Implement comprehensive input validation for all forms
  - Add error display using existing InlineErrorView patterns
  - Integrate with ToastManager for non-critical notifications
  - Add proper error recovery mechanisms
  - Test error scenarios and edge cases
  - _Requirements: 1.3, 1.4, 1.5, 5.4, 6.4_

- [x] 17. Implement data persistence and state management
  - Ensure proper data saving on app backgrounding
  - Add data migration handling for future updates
  - Implement proper cleanup of old completed runs
  - Test data persistence across app launches
  - Add data validation on load with error recovery
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 17.1 Write integration tests for data persistence
  - Test data saving and loading across app launches
  - Test data migration scenarios
  - Test cleanup of old data
  - Test error recovery from corrupted data
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [x] 18. Add haptic feedback and micro-interactions
  - Integrate HapticManager for button interactions
  - Add success feedback for run completion
  - Add light feedback for navigation actions
  - Add heavy feedback for destructive actions (end run)
  - Ensure haptic feedback respects accessibility settings
  - _Requirements: 2.6, 7.4_

- [x] 19. Implement performance optimizations
  - Add lazy loading for large run lists
  - Optimize view updates with proper @Published usage
  - Implement efficient list rendering with LazyVStack
  - Add proper memory management for timers and observers
  - Test performance with large datasets
  - _Requirements: 5.1, 5.2, 7.1, 7.4_

- [x] 20. Final integration and testing
  - Test complete user flow from run creation to completion
  - Verify integration with existing TribeBoard navigation
  - Test data persistence and state management
  - Verify accessibility compliance
  - Test error handling and edge cases
  - Ensure consistent styling with existing app design
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3, 7.4, 7.5_