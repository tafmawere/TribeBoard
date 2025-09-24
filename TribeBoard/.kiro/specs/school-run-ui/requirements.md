# Requirements Document

## Introduction

The School Run UI feature provides a dedicated SwiftUI screen for managing and visualizing school transportation runs within the TribeBoard family coordination app. This is a UI/UX showcase implementation that focuses on visual design and user interaction patterns without backend integration. The screen enables family members to view trip information, track progress, and communicate during school runs through an intuitive interface.

## Requirements

### Requirement 1

**User Story:** As a family member, I want to view the school run screen with a clear header, so that I can easily identify the current screen and navigate back to the family dashboard.

#### Acceptance Criteria

1. WHEN the school run screen loads THEN the system SHALL display a header with the title "School Run"
2. WHEN the header is displayed THEN the system SHALL show a back button that navigates to the Family Dashboard
3. WHEN the header is displayed THEN the system SHALL show the family logo/avatar on the right side

### Requirement 2

**User Story:** As a family member, I want to see a visual representation of the school run route, so that I can understand the trip path and key locations.

#### Acceptance Criteria

1. WHEN the school run screen loads THEN the system SHALL display a map placeholder in the top half with fixed height of approximately 250 points
2. WHEN the map placeholder is shown THEN the system SHALL display a gray rectangle with "Map Placeholder" text
3. WHEN the map is displayed THEN the system SHALL overlay static icons for driver (🚗), school (🏫), and home (🏠) locations
4. WHEN the route is shown THEN the system SHALL draw a simple static line representing the route path

### Requirement 3

**User Story:** As a family member, I want to view detailed trip information in a card format, so that I can quickly access all relevant details about the school run.

#### Acceptance Criteria

1. WHEN the school run screen loads THEN the system SHALL display a trip information card in the bottom half with rounded corners and shadow
2. WHEN the trip card is displayed THEN the system SHALL show a driver info section with static avatar and "John Doe" label
3. WHEN the trip card is displayed THEN the system SHALL show a children section with static avatars of 2-3 kids
4. WHEN the trip card is displayed THEN the system SHALL show destination info with static text "Soccer Practice – 15:30"
5. WHEN the trip card is displayed THEN the system SHALL show ETA section with static "ETA: 15 min" text
6. WHEN the trip card is displayed THEN the system SHALL show a status badge as rounded capsule displaying "Not Started" in gray

### Requirement 4

**User Story:** As a family member, I want to control the school run status and communicate with family, so that I can manage the trip and keep everyone informed.

#### Acceptance Criteria

1. WHEN the trip card is displayed THEN the system SHALL show a large "Start Run" button with primary color and full width
2. WHEN the "Start Run" button is tapped THEN the system SHALL change the button to "End Run" with red background
3. WHEN the trip card is displayed THEN the system SHALL show a secondary "Notify Family" button with outline style
4. WHEN the trip card is displayed THEN the system SHALL show a small circular red "SOS" button at the bottom-right of the card

### Requirement 5

**User Story:** As a family member, I want to navigate between different app sections using a bottom tab menu, so that I can access other features while maintaining context.

#### Acceptance Criteria

1. WHEN the school run screen is displayed THEN the system SHALL show a bottom tab menu with four static items
2. WHEN the bottom tab menu is shown THEN the system SHALL display Dashboard, Calendar, Tasks, and Messages tabs
3. WHEN the bottom tab menu is shown THEN the system SHALL use SF Symbols: house.fill, calendar, checkmark.circle, message.fill
4. WHEN the screen first loads THEN the system SHALL highlight the Dashboard tab as active

### Requirement 6

**User Story:** As a developer, I want the UI to follow TribeBoard design standards, so that the screen maintains visual consistency with the rest of the app.

#### Acceptance Criteria

1. WHEN any UI element is displayed THEN the system SHALL use rounded corners of 20 points where applicable
2. WHEN colors are applied THEN the system SHALL use TribeBoard brandPrimary color for accents
3. WHEN text is displayed THEN the system SHALL use clean, family-friendly fonts (SF Pro)
4. WHEN interactive elements are displayed THEN the system SHALL provide adequate padding for touch targets
5. WHEN the implementation is created THEN the system SHALL use only static placeholder data without backend connections
6. WHEN the implementation is created THEN the system SHALL use SwiftUI components like VStack, HStack, ZStack, and RoundedRectangle