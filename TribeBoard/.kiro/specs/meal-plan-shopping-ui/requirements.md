# Requirements Document

## Introduction

The Meal Plan & Shopping UI Flow is a comprehensive frontend module for the TribeBoard iOS app that enables families to plan meals, check pantry inventory, generate grocery lists, and integrate shopping tasks with family task management. This feature focuses purely on the user interface and navigation flow using placeholder data, without backend connectivity. The module consists of three integrated components: Meal Planning, Grocery & Shopping, and Task Integration, all accessible through a new "HomeLife" navigation tab.

## Requirements

### Requirement 1: Meal Plan Dashboard

**User Story:** As a parent, I want to view our family's monthly meal plan in an organized calendar or list format, so that I can see what meals are planned and what ingredients are needed.

#### Acceptance Criteria

1. WHEN the user opens the Meal Plan Dashboard THEN the system SHALL display a calendar or list view of the monthly meal plan
2. WHEN displaying meal cards THEN the system SHALL show meal name, day, and complete list of required ingredients for each meal
3. WHEN a meal card is displayed THEN the system SHALL include a "Check Pantry" button that navigates to the PantryCheckView
4. WHEN the user views the dashboard THEN the system SHALL use the existing TribeBoard design language, color palette, and logo
5. WHEN the dashboard loads THEN the system SHALL display placeholder meal data in an organized, family-friendly interface

### Requirement 2: Pantry Inventory Check

**User Story:** As a family member, I want to check off ingredients we already have at home, so that I only need to buy what's missing for our planned meals.

#### Acceptance Criteria

1. WHEN the user navigates from a meal card's "Check Pantry" button THEN the system SHALL display all ingredients for the selected week
2. WHEN displaying ingredients THEN the system SHALL provide checkboxes for each item to mark availability in the house
3. WHEN the user completes the pantry check THEN the system SHALL include a "Generate Grocery List" button
4. WHEN the "Generate Grocery List" button is tapped THEN the system SHALL navigate to the GroceryListView
5. WHEN ingredients are displayed THEN the system SHALL organize them in a clear, scannable list format

### Requirement 3: Grocery List Management

**User Story:** As a family member, I want to manage both auto-generated grocery lists and manually added urgent items, so that I can handle all our shopping needs in one place.

#### Acceptance Criteria

1. WHEN the user opens the GroceryListView THEN the system SHALL display two tabs: "Weekly Grocery List" and "Urgent Additions"
2. WHEN displaying the "Weekly Grocery List" tab THEN the system SHALL show auto-generated items from the pantry check
3. WHEN displaying the "Urgent Additions" tab THEN the system SHALL show manually inputted items by family members
4. WHEN displaying grocery items THEN the system SHALL show name, quantity, added by (helper/parent), and linked meal for each item
5. WHEN the grocery list is displayed THEN the system SHALL include an "Order Online" button that navigates to OrderPlatformSelectionView
6. WHEN no urgent items exist THEN the system SHALL display an appropriate empty state message

### Requirement 4: Online Order Platform Selection

**User Story:** As a family member, I want to choose from available grocery delivery platforms, so that I can order our groceries through my preferred service.

#### Acceptance Criteria

1. WHEN the user taps "Order Online" THEN the system SHALL display the OrderPlatformSelectionView with platform cards
2. WHEN displaying platform options THEN the system SHALL show UI cards for Woolies Dash, Checkers 360, and Pick n Pay
3. WHEN a platform card is tapped THEN the system SHALL simulate sending the grocery list with a placeholder action
4. WHEN platform cards are displayed THEN the system SHALL use clear, recognizable branding and layout
5. WHEN the simulation completes THEN the system SHALL provide appropriate user feedback

### Requirement 5: Task Creation Integration

**User Story:** As a parent, I want to convert urgent grocery items into assigned family tasks, so that I can delegate shopping responsibilities with clear instructions.

#### Acceptance Criteria

1. WHEN the user accesses TaskCreationView THEN the system SHALL allow adding urgent items as assignable tasks
2. WHEN creating a task THEN the system SHALL allow assignment to a specific family member
3. WHEN creating a task THEN the system SHALL provide task type options: "Shop Run" and "School Run + Shop Stop"
4. WHEN creating a task THEN the system SHALL allow adding due time and notes
5. WHEN a task includes location stops THEN the system SHALL use map placeholders for location display

### Requirement 6: Task List Management

**User Story:** As a family member, I want to view and filter pending shopping tasks, so that I can see what needs to be done and by whom.

#### Acceptance Criteria

1. WHEN the user opens TaskListView THEN the system SHALL display pending tasks with status badges
2. WHEN displaying tasks THEN the system SHALL provide filtering options by person and due date
3. WHEN tasks are displayed THEN the system SHALL show clear status indicators and task details
4. WHEN no tasks exist THEN the system SHALL display an appropriate empty state
5. WHEN tasks include shopping stops THEN the system SHALL integrate with the grocery list data

### Requirement 7: HomeLife Navigation Integration

**User Story:** As a family member, I want to access all meal planning and shopping features through a dedicated navigation tab, so that I can easily switch between related functions.

#### Acceptance Criteria

1. WHEN the app loads THEN the system SHALL include a "HomeLife" tab in the bottom navigation
2. WHEN the HomeLife tab is selected THEN the system SHALL provide navigation to Meal Plan, Pantry, Grocery List, and Tasks
3. WHEN navigating between HomeLife features THEN the system SHALL maintain consistent navigation patterns
4. WHEN using navigation THEN the system SHALL use clear iconography including 🍽️ 🛒 ✅ symbols
5. WHEN navigation is displayed THEN the system SHALL follow existing TribeBoard navigation conventions

### Requirement 8: Design System Compliance

**User Story:** As a user, I want the meal planning interface to feel integrated with the rest of TribeBoard, so that I have a consistent and familiar experience.

#### Acceptance Criteria

1. WHEN any view is displayed THEN the system SHALL use the existing TribeBoard logo, color palette, and design language
2. WHEN the interface is used THEN the system SHALL support both light and dark mode themes
3. WHEN displaying content THEN the system SHALL use modern, family-oriented design patterns
4. WHEN showing empty states THEN the system SHALL provide helpful and encouraging messaging
5. WHEN using iconography THEN the system SHALL maintain consistency with existing TribeBoard icon usage

### Requirement 9: Data Management

**User Story:** As a developer, I want the UI to function with placeholder data, so that the interface can be built and tested without backend dependencies.

#### Acceptance Criteria

1. WHEN the app loads meal data THEN the system SHALL use realistic placeholder meal plans and ingredients
2. WHEN displaying family members THEN the system SHALL use placeholder family member data
3. WHEN showing grocery platforms THEN the system SHALL use placeholder platform information
4. WHEN tasks are created THEN the system SHALL store data locally for the session
5. WHEN placeholder data is used THEN the system SHALL ensure it represents realistic family scenarios