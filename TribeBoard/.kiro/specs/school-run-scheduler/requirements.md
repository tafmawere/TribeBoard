# Requirements Document

## Introduction

The School Run Scheduler feature provides a comprehensive multi-screen system for creating, managing, and executing structured school runs within the TribeBoard family coordination app. This is a UX-focused implementation that enables parents to schedule runs with multiple stops, assign children to specific stops, track tasks, and execute runs step-by-step. The feature uses placeholder data for maps and real-time updates while maintaining consistency with TribeBoard's existing design system and branding.

## Requirements

### Requirement 1

**User Story:** As a parent, I want to access a School Run Dashboard, so that I can quickly see my upcoming and past runs and create new ones.

#### Acceptance Criteria

1. WHEN the School Run Dashboard loads THEN the system SHALL display the title "School Runs" at the top
2. WHEN the dashboard is displayed THEN the system SHALL show a "➕ Schedule New Run" button prominently
3. WHEN the dashboard is displayed THEN the system SHALL show a "📅 View Scheduled Runs" button
4. WHEN the dashboard is displayed THEN the system SHALL show an "Upcoming Runs" section with a list of scheduled run templates
5. WHEN upcoming runs are shown THEN each item SHALL display day, time, and stops summary
6. WHEN the dashboard is displayed THEN the system SHALL show a "Past Runs" section with completed runs for reference
7. WHEN past runs are shown THEN each item SHALL display completion date and basic run details

### Requirement 2

**User Story:** As a parent, I want to schedule a new school run with multiple stops and child assignments, so that I can create structured transportation plans.

#### Acceptance Criteria

1. WHEN the Schedule New Run screen loads THEN the system SHALL display a form with input fields for run details
2. WHEN the form is displayed THEN the system SHALL provide a "Run Name" text input field
3. WHEN the form is displayed THEN the system SHALL provide day selection using a date picker component
4. WHEN the form is displayed THEN the system SHALL provide time selection using a time picker component
5. WHEN the form is displayed THEN the system SHALL show an "Add Stops" section with drag-and-drop capability
6. WHEN the Add Stops section is shown THEN the system SHALL display an "➕ Add Stop" button
7. WHEN a stop is added THEN the system SHALL provide fields for Stop Name, Assign Child, Task, and Estimated Stop Time
8. WHEN Stop Name is selected THEN the system SHALL offer preset options: Home, School, OT, Music, Custom
9. WHEN Assign Child is selected THEN the system SHALL show a dropdown with available children profiles
10. WHEN Task is entered THEN the system SHALL accept short text input for stop-specific tasks
11. WHEN Estimated Stop Time is entered THEN the system SHALL accept time in minutes
12. WHEN stops are configured THEN the system SHALL display a placeholder map thumbnail for each stop
13. WHEN the form is complete THEN the system SHALL provide a "💾 Save Run" button to store the configuration

### Requirement 3

**User Story:** As a parent, I want to view my scheduled runs in a list format, so that I can easily browse and select runs to view or execute.

#### Acceptance Criteria

1. WHEN the Scheduled Runs screen loads THEN the system SHALL display a list view of all created runs
2. WHEN runs are listed THEN each item SHALL show the Run Name prominently
3. WHEN runs are listed THEN each item SHALL display the scheduled Day & Time
4. WHEN runs are listed THEN each item SHALL show the Number of Stops configured
5. WHEN a run item is tapped THEN the system SHALL navigate to the Run Detail screen
6. WHEN the list is empty THEN the system SHALL show an appropriate empty state message

### Requirement 4

**User Story:** As a parent, I want to view detailed information about a scheduled run, so that I can review the plan before starting execution.

#### Acceptance Criteria

1. WHEN the Run Detail screen loads THEN the system SHALL display the Run Name as the title
2. WHEN run details are shown THEN the system SHALL display a Run Overview section with Day, Time, and Duration
3. WHEN run details are shown THEN the system SHALL list all stops in sequential order
4. WHEN stops are listed THEN each stop SHALL show the stop number, location name, assigned child, and scheduled time
5. WHEN stops are listed THEN each stop SHALL display associated tasks (e.g., "Pick snacks & guitar")
6. WHEN the run detail is complete THEN the system SHALL provide a prominent "▶️ Start Run" button
7. WHEN the Start Run button is tapped THEN the system SHALL navigate to Run Execution Mode

### Requirement 5

**User Story:** As a parent, I want to execute a school run step-by-step with visual guidance, so that I can follow the planned route and complete all tasks efficiently.

#### Acceptance Criteria

1. WHEN Run Execution Mode starts THEN the system SHALL display a placeholder map view at the top of the screen
2. WHEN execution mode is active THEN the system SHALL show current stop instructions prominently
3. WHEN current stop is displayed THEN the system SHALL show the stop title (e.g., "Stop 1 of 6: Home")
4. WHEN current stop is displayed THEN the system SHALL show the associated task for that stop
5. WHEN execution controls are shown THEN the system SHALL provide a "✅ Done → Next Stop" button
6. WHEN execution controls are shown THEN the system SHALL provide a "⏸ Pause Run" button
7. WHEN execution controls are shown THEN the system SHALL provide a "❌ Cancel Run" button
8. WHEN progress is tracked THEN the system SHALL display a progress bar showing current stop position
9. WHEN a stop is completed THEN the system SHALL advance to the next stop automatically
10. WHEN the final stop is completed THEN the system SHALL show run completion confirmation

### Requirement 6

**User Story:** As a parent, I want to receive feedback and notifications during run execution, so that I stay informed about my progress and can communicate with family.

#### Acceptance Criteria

1. WHEN a stop is completed THEN the system SHALL display a toast notification confirming "Stop Completed"
2. WHEN a run is started THEN the system SHALL display a toast notification confirming "Run Started"
3. WHEN a run is paused THEN the system SHALL display a toast notification confirming "Run Paused"
4. WHEN a run is cancelled THEN the system SHALL display a toast notification confirming "Run Cancelled"
5. WHEN a run is completed THEN the system SHALL display a toast notification confirming "Run Completed"
6. WHEN notifications are shown THEN the system SHALL use consistent toast styling with TribeBoard branding

### Requirement 7

**User Story:** As a developer, I want the School Run Scheduler to maintain design consistency with TribeBoard, so that users experience a cohesive interface.

#### Acceptance Criteria

1. WHEN any screen is displayed THEN the system SHALL use the existing TribeBoard logo and branding elements
2. WHEN colors are applied THEN the system SHALL use the established TribeBoard color scheme and BrandColors
3. WHEN UI components are rendered THEN the system SHALL follow TribeBoard's DesignSystem patterns
4. WHEN buttons are displayed THEN the system SHALL use existing ButtonStyles from the TribeBoard design system
5. WHEN navigation is implemented THEN the system SHALL integrate with the existing MainNavigationView structure
6. WHEN typography is applied THEN the system SHALL use consistent fonts and text styles from DesignSystem
7. WHEN spacing and layout are applied THEN the system SHALL follow established padding and margin patterns

### Requirement 8

**User Story:** As a developer, I want the implementation to use placeholder data and static content, so that the UX can be demonstrated without backend dependencies.

#### Acceptance Criteria

1. WHEN maps are displayed THEN the system SHALL use static placeholder images instead of live MapKit integration
2. WHEN navigation is shown THEN the system SHALL use placeholder routing without real-time GPS data
3. WHEN children profiles are loaded THEN the system SHALL use static mock data for demonstration
4. WHEN runs are saved THEN the system SHALL store data locally without CloudKit or database integration
5. WHEN real-time updates are simulated THEN the system SHALL use local state management and timers
6. WHEN the implementation is complete THEN the system SHALL function entirely as a frontend demonstration