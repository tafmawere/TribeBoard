# Requirements Document

## Introduction

The Family Setup & Roles module enables users to create or join family groups within TribeBoard, manage family member roles, and provide a foundation for family-based features. The system supports secure authentication via Sign in with Apple, role-based permissions, and seamless synchronization between local storage and CloudKit for multi-device access.

## Requirements

### Requirement 1: User Authentication

**User Story:** As a new user, I want to sign in with my Apple ID so that I can securely access TribeBoard and maintain my identity across devices.

#### Acceptance Criteria

1. WHEN a user opens the app for the first time THEN the system SHALL display the onboarding screen with "Sign in with Apple" option
2. WHEN a user taps "Sign in with Apple" THEN the system SHALL initiate ASAuthorizationAppleID authentication flow
3. WHEN authentication succeeds THEN the system SHALL create or fetch a UserProfile with appleUserIdHash stored in Keychain and SwiftData
4. WHEN authentication fails THEN the system SHALL display an appropriate error message and allow retry
5. IF a user has previously authenticated THEN the system SHALL automatically sign them in using stored credentials

### Requirement 2: Family Creation

**User Story:** As a parent, I want to create a new family group so that I can invite other family members to join our shared space.

#### Acceptance Criteria

1. WHEN an authenticated user navigates to CreateFamily_Screen THEN the system SHALL display a family name input field
2. WHEN a user enters a valid family name and submits THEN the system SHALL create a Family record in SwiftData and CloudKit
3. WHEN a family is created THEN the system SHALL generate a unique 6-8 character alphanumeric family code that is collision-safe
4. WHEN a family code is generated THEN the system SHALL create a QR code image for local display
5. WHEN a family is created THEN the system SHALL automatically create a Membership record for the creator with Role.parentAdmin
6. WHEN family creation completes THEN the system SHALL navigate to the family dashboard

### Requirement 3: Family Joining

**User Story:** As a family member, I want to join an existing family using a code or QR scan so that I can participate in family activities.

#### Acceptance Criteria

1. WHEN an authenticated user navigates to JoinFamily_Screen THEN the system SHALL display options to enter a family code or scan QR code
2. WHEN a user enters a family code THEN the system SHALL query CloudKit to resolve the Family by code
3. WHEN a user scans a QR code THEN the system SHALL extract the family code and resolve the Family
4. WHEN a valid family is found THEN the system SHALL display confirmation showing family name and member count
5. WHEN a user confirms joining THEN the system SHALL create a Membership record with default Role.adult
6. WHEN family code is invalid THEN the system SHALL display an error message
7. WHEN join operation completes THEN the system SHALL navigate to role selection screen

### Requirement 4: Role Management

**User Story:** As a family member, I want to select my role in the family so that I have appropriate permissions and access levels.

#### Acceptance Criteria

1. WHEN a user accesses RoleSelection_Screen THEN the system SHALL display available roles: Parent Admin, Adult, Kid, Visitor
2. WHEN a user selects a role other than Parent Admin THEN the system SHALL update their Membership.role and sync to CloudKit
3. WHEN a user attempts to select Parent Admin AND one already exists THEN the system SHALL display an error and default to Adult role
4. WHEN a user attempts to select Parent Admin AND none exists THEN the system SHALL allow the selection
5. WHEN role selection completes THEN the system SHALL navigate to family dashboard
6. WHEN role changes are made THEN the system SHALL persist changes in SwiftData and sync to CloudKit

### Requirement 5: Family Dashboard and Member Management

**User Story:** As a family member, I want to view all family members and their roles so that I understand the family structure.

#### Acceptance Criteria

1. WHEN a user accesses FamilyDashboard_Screen THEN the system SHALL display all active family members with avatar, displayName, and role badge
2. WHEN a Parent Admin views the dashboard THEN the system SHALL provide options to change member roles or remove members
3. WHEN a non-admin user views the dashboard THEN the system SHALL display read-only member information
4. WHEN a Parent Admin removes a member THEN the system SHALL set Membership.status to removed (soft delete)
5. WHEN a Parent Admin changes a member's role THEN the system SHALL update the Membership record and sync to CloudKit
6. WHEN member data changes THEN the system SHALL reflect updates in real-time across all devices

### Requirement 6: Data Synchronization and Offline Support

**User Story:** As a user, I want my family data to sync across all my devices and work offline so that I can access information anytime.

#### Acceptance Criteria

1. WHEN data changes are made THEN the system SHALL write to SwiftData first and enqueue CloudKit operations
2. WHEN CloudKit operations succeed THEN the system SHALL mark local changes as synced
3. WHEN CloudKit operations fail THEN the system SHALL retry with exponential backoff
4. WHEN conflicts occur THEN the system SHALL use last-write-wins for Membership.role changes
5. WHEN the device is offline THEN the system SHALL read from SwiftData and queue CloudKit operations for later
6. WHEN conflicts are resolved THEN the system SHALL display a non-blocking banner notification

### Requirement 7: Security and Privacy

**User Story:** As a user, I want my family data to be secure and private so that sensitive information is protected.

#### Acceptance Criteria

1. WHEN storing user data THEN the system SHALL only store necessary PII (displayName, avatar URL)
2. WHEN generating QR codes THEN the system SHALL not embed QR images in CloudKit, only store code strings
3. WHEN storing sensitive data THEN the system SHALL use Keychain to store appleUserIdHash and current familyId
4. WHEN accessing CloudKit THEN the system SHALL use private database with custom zones and CKRecords
5. WHEN handling authentication THEN the system SHALL follow Apple's Sign in with Apple best practices

### Requirement 8: Code Generation and Validation

**User Story:** As a system, I need to generate unique family codes so that families can be identified and joined securely.

#### Acceptance Criteria

1. WHEN generating a family code THEN the system SHALL create a 6-8 character alphanumeric code
2. WHEN checking code uniqueness THEN the system SHALL verify no existing family uses the same code
3. WHEN a collision is detected THEN the system SHALL generate a new code and retry
4. WHEN validating input codes THEN the system SHALL check format and existence in CloudKit
5. WHEN codes are generated THEN the system SHALL ensure they are easily readable and shareable