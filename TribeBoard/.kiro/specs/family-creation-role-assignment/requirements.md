# Requirements Document

## Introduction

This feature enhances the existing TribeBoard frontend by adding functionality for family creation and role assignment. The implementation will connect logic to existing UI components without redesigning the interface, using local in-memory data models for ephemeral storage that persists only during the app session.

## Requirements

### Requirement 1

**User Story:** As a parent, I want to create a new family with a unique code, so that other family members can join using that code.

#### Acceptance Criteria

1. WHEN the "Create Family" button is tapped THEN the system SHALL generate a unique family ID using UUID
2. WHEN a family is created THEN the system SHALL generate a random alphanumeric family code (format: "ABC123")
3. WHEN a family is created THEN the system SHALL store the new Family object in memory with structure { id, name, code, members[] }
4. WHEN a family is created THEN the system SHALL display the generated family code on screen
5. WHEN a family is created THEN the system SHALL navigate to Role Selection with the created family context

### Requirement 2

**User Story:** As a family member, I want to join an existing family using a family code, so that I can become part of that family group.

#### Acceptance Criteria

1. WHEN the "Join Family" button is tapped THEN the system SHALL check if the entered family code matches an existing family in memory
2. IF the family code is valid THEN the system SHALL navigate to Role Selection with that family context
3. IF the family code is invalid THEN the system SHALL show an error toast or alert message
4. WHEN joining a family THEN the system SHALL validate the code format before processing

### Requirement 3

**User Story:** As a family member, I want to select and assign my role within the family, so that my permissions and responsibilities are properly defined.

#### Acceptance Criteria

1. WHEN a role card is tapped THEN the system SHALL highlight the selected role visually
2. WHEN "Confirm Role" is tapped THEN the system SHALL assign the selected role to the current user
3. WHEN a role is confirmed THEN the system SHALL add the user to the Family.members list with structure { id, name, role }
4. WHEN a role is confirmed THEN the system SHALL navigate to Family Dashboard
5. WHEN role selection is active THEN the system SHALL support roles: Parent, Child, Guardian, Helper

### Requirement 4

**User Story:** As a family member, I want to view the family dashboard showing all members and their roles, so that I can see the current family structure.

#### Acceptance Criteria

1. WHEN the Family Dashboard loads THEN the system SHALL display the current family name
2. WHEN the Family Dashboard loads THEN the system SHALL display all members from Family.members with their assigned roles
3. WHEN the "Add Member" button is tapped THEN the system SHALL navigate back to Join Family flow
4. WHEN viewing the dashboard THEN the system SHALL show member information in a clear, organized format

### Requirement 5

**User Story:** As a developer, I want all family data to be stored in memory only, so that the implementation remains simple and self-contained without external dependencies.

#### Acceptance Criteria

1. WHEN the app starts THEN the system SHALL initialize empty in-memory storage for family data
2. WHEN the app is restarted THEN the system SHALL clear all previously stored family data
3. WHEN managing family data THEN the system SHALL use @StateObject or ObservableObject patterns
4. WHEN storing data THEN the system SHALL NOT use database, CloudKit, or backend services
5. WHEN implementing data models THEN the system SHALL keep all functionality self-contained within the current module