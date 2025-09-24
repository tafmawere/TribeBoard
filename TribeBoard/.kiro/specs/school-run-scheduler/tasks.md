# Implementation Plan

- [x] 1. Create core data models and mock data provider
  - Implement SchoolRun struct with id, name, dates, stops, and computed properties for duration and participating children
  - Create RunStop struct with id, name, type enum, assigned child, task, and estimated minutes
  - Define ChildProfile struct with id, name, avatar, and age properties
  - Implement RunExecutionState enum for tracking execution status
  - Create MockDataProvider class with static sample children, runs, and map placeholders
  - _Requirements: 8.3, 8.4, 8.5_

- [x] 2. Implement SchoolRunManager for state management
  - Create SchoolRunManager as ObservableObject to handle run data persistence
  - Implement methods for saving, loading, and deleting runs using UserDefaults
  - Add functionality for creating new runs and updating existing ones
  - Implement run execution state management and progress tracking
  - Create methods for filtering upcoming vs past runs based on dates
  - _Requirements: 8.4, 8.5_

- [x] 3. Create ToastNotificationManager for user feedback
  - Implement ToastNotificationManager as ObservableObject for showing notifications
  - Define ToastMessage struct with text, type, and color properties
  - Create show() method with automatic dismissal after 3 seconds
  - Implement ToastView component with proper styling and animations
  - Add toast overlay modifier for easy integration across screens
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 4. Build reusable UI components
  - Create RunSummaryCard component for displaying run overview with day, time, and stops count
  - Implement StopConfigurationRow for form-based stop editing with all input fields
  - Build MapPlaceholderView component with static placeholder image and location indicators
  - Create ProgressIndicator component for execution mode with visual progress bar
  - Implement CurrentStopCard for execution mode showing current stop details and tasks
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [x] 5. Implement SchoolRunDashboardView as main entry point
  - Create SchoolRunDashboardView with NavigationStack and ScrollView layout
  - Add header section with "School Runs" title using TribeBoard typography
  - Implement ActionButtonsSection with "Schedule New Run" and "View Scheduled Runs" buttons
  - Create UpcomingRunsSection displaying list of scheduled runs using RunSummaryCard
  - Add PastRunsSection showing completed runs for reference
  - Integrate with SchoolRunManager for data loading and navigation state management
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_

- [x] 6. Create ScheduleNewRunView for run creation
  - Build form-based interface using SwiftUI Form with sections for run details and stops
  - Implement run name TextField with proper validation and styling
  - Add DatePicker for day selection and separate DatePicker for time selection
  - Create dynamic stops section with ForEach displaying StopConfigurationRow components
  - Implement "Add Stop" button functionality to append new stops to array
  - Add StopPresetPicker with Home, School, OT, Music, Custom options
  - Implement ChildSelectionPicker dropdown populated with mock child profiles
  - Add save functionality that validates form and creates new SchoolRun object
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13_

- [x] 7. Build ScheduledRunsListView for browsing runs
  - Create NavigationView with List displaying all scheduled runs
  - Implement RunListRowView component showing run name, day/time, and stop count
  - Add NavigationLink integration to navigate to RunDetailView when row is tapped
  - Create EmptyStateView for when no scheduled runs exist
  - Integrate with SchoolRunManager to load and display scheduled runs data
  - Add proper list styling consistent with TribeBoard design system
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 8. Implement RunDetailView for reviewing run details
  - Create ScrollView layout with VStack containing run overview and stops list
  - Build RunOverviewCard component displaying day, time, duration, and participant summary
  - Implement stops list using ForEach with StopDetailRow components
  - Create StopDetailRow showing stop number, location, assigned child, and tasks
  - Add prominent "Start Run" button using PrimaryButtonStyle
  - Implement navigation to RunExecutionView when start button is tapped
  - Apply proper spacing and styling consistent with TribeBoard design patterns
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

- [x] 9. Create RunExecutionView for step-by-step execution
  - Build VStack layout with MapPlaceholderView in top half and controls in bottom half
  - Implement MapPlaceholderView with static placeholder image and current location indicator
  - Create CurrentStopCard displaying current stop title and associated task prominently
  - Add ProgressIndicator showing current stop position out of total stops
  - Implement ExecutionControls with "Done → Next Stop", "Pause Run", and "Cancel Run" buttons
  - Add state management for currentStopIndex and executionState tracking
  - Implement completeCurrentStop() method to advance to next stop with toast feedback
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10_

- [x] 10. Add navigation integration and routing
  - Integrate all screens with existing MainNavigationView structure
  - Implement proper NavigationStack paths for deep linking between screens
  - Add back button functionality and navigation bar styling consistent with TribeBoard
  - Ensure FloatingBottomNavigation remains accessible across all screens
  - Test navigation flow from dashboard through creation, browsing, detail, and execution
  - _Requirements: 7.5_

- [x] 11. Implement form validation and error handling
  - Create RunValidation utility with validateRun() method checking name, stops, and durations
  - Add ValidationError enum with localized error descriptions
  - Implement form validation in ScheduleNewRunView with error display
  - Add confirmation alerts for destructive actions like cancelling runs
  - Implement proper error states and user feedback throughout all screens
  - _Requirements: 2.13, 5.7_

- [x] 12. Add toast notifications and user feedback
  - Integrate ToastNotificationManager across all screens for user feedback
  - Implement "Stop Completed" toast when advancing in execution mode
  - Add "Run Started" toast when beginning execution
  - Create "Run Paused" and "Run Cancelled" toasts for execution controls
  - Implement "Run Completed" toast when finishing final stop
  - Add "Run Saved" toast when successfully creating new run
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 13. Apply TribeBoard design system styling
  - Use existing TribeBoard logo and branding elements in headers and navigation
  - Apply BrandColors throughout all screens for consistent color scheme
  - Implement ButtonStyles from existing TribeBoard design system
  - Use DesignSystem typography for all text elements and proper hierarchy
  - Apply consistent spacing and padding patterns using DesignSystem values
  - Ensure rounded corners and shadows match existing TribeBoard component styling
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [x] 14. Implement placeholder data and static content
  - Replace all map components with static placeholder images instead of MapKit
  - Use mock data for all children profiles, runs, and navigation without real-time GPS
  - Implement local storage using UserDefaults instead of CloudKit integration
  - Create static route visualizations and location indicators for execution mode
  - Ensure all functionality works entirely as frontend demonstration without backend
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

- [x] 15. Add accessibility support and testing
  - Implement proper accessibility labels and hints for all interactive elements
  - Ensure VoiceOver compatibility for navigation and form interactions
  - Test dynamic type scaling for all text elements across screens
  - Verify high contrast mode compatibility for colors and visual elements
  - Add accessibility identifiers for UI testing of complete user flows
  - _Requirements: 7.6_

- [x] 16. Create comprehensive SwiftUI previews
  - Add multiple preview configurations for each screen showing different states
  - Include dark mode previews to verify color scheme compatibility across all screens
  - Create accessibility previews with large text size for form and execution screens
  - Add interactive previews demonstrating button interactions and state changes
  - Implement preview data providers for consistent mock data across all previews
  - _Requirements: 8.6_