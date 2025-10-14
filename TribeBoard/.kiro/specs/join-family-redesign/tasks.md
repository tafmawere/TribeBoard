# Implementation Plan

- [x] 1. Create new card-based components for the redesigned interface
  - Create FamilyCodeCard component with white background, shadow, and proper spacing
  - Implement search icon header and "Enter Family Code" title
  - Add input field with "Family Code" label and "Enter 6-digit code" placeholder
  - Integrate paste functionality for the input field
  - Style the "Find Family" button with proper enabled/disabled states
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

- [x] 2. Implement QR code scanning section with green accent styling using SwiftUI
  - Create QRCodeScanSection component with QR icon and "Scan QR Code" text
  - Style the scan button with green accent color and rounded corners
  - Add "From family invitation" descriptive text below the button
  - Use SwiftUI's native QR code scanning capabilities and UI components
  - Ensure proper spacing and alignment within the section
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 3. Create supporting UI components for layout structure
  - Implement OrDivider component with centered "or" text and subtle styling
  - Create InstructionalFooter component with family sharing instructions
  - Add proper spacing and typography for both components
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 4. Update main JoinFamilyView layout to use card-based design
  - Replace gradient background with light system background
  - Restructure main VStack to use new card components
  - Implement proper spacing (24pt between major sections)
  - Update navigation title and back button handling
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 5. Integrate paste functionality for family code input
  - Add paste button that appears when input field is focused
  - Implement clipboard detection and paste action
  - Style paste button to match the design requirements
  - Handle paste validation and error states
  - _Requirements: 2.5_

- [x] 6. Apply brand colors and styling consistency
  - Ensure all components use existing BrandPrimary and BrandSecondary colors appropriately
  - Apply proper card shadows and corner radius using BrandStyle
  - Implement green accent color for QR scan button
  - Maintain color contrast ratios for accessibility
  - _Requirements: 4.4, 5.4_

- [x] 7. Implement responsive design and accessibility features
  - Add proper accessibility labels and hints to all new components
  - Ensure keyboard navigation works correctly with new layout
  - Test and adjust spacing for different screen sizes
  - Verify haptic feedback integration with new button interactions
  - _Requirements: 5.1, 5.2, 5.3, 5.5_

- [x] 8. Write unit tests for new components
  - Test FamilyCodeCard component behavior and state management
  - Test QRCodeScanSection component interactions
  - Test paste functionality and validation
  - Test accessibility features of new components
  - _Requirements: All requirements_

- [x] 9. Update existing error handling to work with card layout
  - Modify error message display to work within card boundaries
  - Ensure inline validation messages appear correctly in new layout
  - Test alert dialogs and confirmation dialogs with new design
  - Verify loading states display properly in card components
  - _Requirements: 2.6, 2.7, 3.6_

- [x] 10. Final integration and polish
  - Integrate all new components into the main JoinFamilyView
  - Test complete user flow from navigation to family joining
  - Verify all existing functionality works with new design
  - Apply final styling touches and spacing adjustments
  - _Requirements: All requirements_