# Implementation Plan

- [x] 1. Update NavigationTab enum to remove messages tab
  - Remove the `.messages` case from the NavigationTab enum
  - Remove messages-related display name, icon, and activeIcon properties
  - Verify homelife tab retains proper "house.heart" and "house.heart.fill" icons
  - _Requirements: 1.1, 1.2, 2.1, 2.2_

- [x] 2. Update MainNavigationView to remove messages references
  - Remove messages case from `dashboardContent` computed property
  - Remove messages case from `destinationView(for:)` method
  - Remove MessagesPlaceholderView and related placeholder handling
  - Add fallback logic to default to dashboard if messages was previously selected
  - _Requirements: 1.1, 1.3, 3.4_

- [x] 3. Clean up messages-related placeholder views and imports
  - Remove MessagesPlaceholderView struct definition
  - Remove any unused imports related to messaging functionality
  - Verify MessagingView import is removed if no longer needed
  - _Requirements: 1.2, 3.3_

- [x] 4. Update navigation state handling for 5-tab layout
  - Ensure AppState properly handles navigation with 5 tabs
  - Add validation that selectedNavigationTab defaults appropriately
  - Test that navigation path handling works with reduced tab count
  - _Requirements: 1.3, 3.1, 3.4_

- [x] 5. Verify accessibility and layout with updated navigation
  - Test that FloatingBottomNavigation displays 5 tabs correctly
  - Verify touch targets and spacing work properly with fewer tabs
  - Ensure accessibility labels and hints are accurate for remaining tabs
  - Test homelife tab icon displays correctly in both active and inactive states
  - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3_