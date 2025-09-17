# CloudKit Schema Setup Guide

This document provides instructions for setting up the CloudKit schema in the CloudKit Console for the TribeBoard Family Setup & Roles module.

## Prerequisites

1. Apple Developer Account with CloudKit access
2. TribeBoard app configured with CloudKit container
3. Access to CloudKit Console (https://icloud.developer.apple.com/)

## Container Configuration

### Container Identifier
- **Container ID**: `iCloud.net.dataenvy.TribeBoard`
- **Environment**: Development (for testing) and Production

## Custom Zone Setup

### Zone Configuration
- **Zone Name**: `TribeBoardZone`
- **Zone Type**: Custom Zone (required for subscriptions and atomic operations)

## Record Types

### 1. CKFamily

**Record Type Name**: `CKFamily`

**Fields**:
| Field Name | Type | Indexed | Queryable | Sortable |
|------------|------|---------|-----------|----------|
| `name` | String | No | No | No |
| `code` | String | Yes | Yes | No |
| `createdByUserId` | String | Yes | Yes | No |
| `createdAt` | Date/Time | No | No | Yes |

**Indexes**:
- **Family Code Index**: 
  - Field: `code`
  - Type: QUERYABLE
  - Purpose: Fast lookup of families by invitation code
- **Creator Index**:
  - Field: `createdByUserId` 
  - Type: QUERYABLE
  - Purpose: Find families created by specific users

**Security Roles**:
- **World**: No Access
- **Authenticated**: Read/Write (users can only access their own family data through app logic)

### 2. CKUserProfile

**Record Type Name**: `CKUserProfile`

**Fields**:
| Field Name | Type | Indexed | Queryable | Sortable |
|------------|------|---------|-----------|----------|
| `displayName` | String | No | No | No |
| `appleUserIdHash` | String | Yes | Yes | No |
| `avatarUrl` | String | No | No | No |
| `createdAt` | Date/Time | No | No | Yes |

**Indexes**:
- **Apple ID Hash Index**:
  - Field: `appleUserIdHash`
  - Type: QUERYABLE
  - Purpose: Fast lookup of user profiles by Apple ID hash

**Security Roles**:
- **World**: No Access
- **Authenticated**: Read/Write (users can only access their own profile through app logic)

### 3. CKMembership

**Record Type Name**: `CKMembership`

**Fields**:
| Field Name | Type | Indexed | Queryable | Sortable |
|------------|------|---------|-----------|----------|
| `role` | String | Yes | Yes | No |
| `joinedAt` | Date/Time | No | No | Yes |
| `status` | String | Yes | Yes | No |
| `lastRoleChangeAt` | Date/Time | No | No | Yes |
| `family` | Reference (CKFamily) | Yes | Yes | No |
| `user` | Reference (CKUserProfile) | Yes | Yes | No |

**Indexes**:
- **Family Membership Index**:
  - Field: `family`
  - Type: QUERYABLE
  - Purpose: Find all members of a specific family
- **User Membership Index**:
  - Field: `user`
  - Type: QUERYABLE
  - Purpose: Find all family memberships for a specific user
- **Active Membership Index**:
  - Fields: `family`, `status`
  - Type: QUERYABLE
  - Purpose: Find active members of a family
- **Role Index**:
  - Field: `role`
  - Type: QUERYABLE
  - Purpose: Query members by role (e.g., find parent admins)

**Reference Actions**:
- `family` reference: **Delete Self** (when family is deleted, remove memberships)
- `user` reference: **Delete Self** (when user is deleted, remove memberships)

**Security Roles**:
- **World**: No Access
- **Authenticated**: Read/Write (users can only access memberships for families they belong to through app logic)

## Subscriptions Setup

The app automatically creates the following subscriptions when `setupSubscriptions()` is called:

### 1. Family Changes Subscription
- **Subscription ID**: `family-changes`
- **Record Type**: `CKFamily`
- **Zone**: `TribeBoardZone`
- **Fires On**: Record Creation, Update, Deletion
- **Notification**: Content Available (silent push)

### 2. Membership Changes Subscription
- **Subscription ID**: `membership-changes`
- **Record Type**: `CKMembership`
- **Zone**: `TribeBoardZone`
- **Fires On**: Record Creation, Update, Deletion
- **Notification**: Content Available (silent push)

### 3. User Profile Changes Subscription
- **Subscription ID**: `userprofile-changes`
- **Record Type**: `CKUserProfile`
- **Zone**: `TribeBoardZone`
- **Fires On**: Record Creation, Update, Deletion
- **Notification**: Content Available (silent push)

## Setup Instructions

### Step 1: Access CloudKit Console
1. Go to https://icloud.developer.apple.com/
2. Sign in with your Apple Developer Account
3. Select your TribeBoard container

### Step 2: Create Record Types
1. Navigate to "Schema" → "Record Types"
2. Create each record type (CKFamily, CKUserProfile, CKMembership) with the fields specified above
3. Configure indexes for each record type as specified
4. Set up reference relationships for CKMembership

### Step 3: Configure Security
1. Navigate to "Schema" → "Security Roles"
2. Ensure "World" has no access to any record types
3. Ensure "Authenticated" users have Read/Write access (app logic will enforce proper access control)

### Step 4: Deploy Schema
1. After creating all record types and indexes in Development environment
2. Deploy the schema to Production when ready for release
3. Test the schema with the app in Development environment first

### Step 5: Verify Setup
1. Run the app and call `CloudKitService.performInitialSetup()`
2. Check that the custom zone is created
3. Verify that subscriptions are set up correctly
4. Test record creation, querying, and real-time updates

## Testing Queries

Use CloudKit Console's "Data" section to test these common queries:

### Find Family by Code
```
Record Type: CKFamily
Predicate: code == "ABC123"
```

### Find User by Apple ID Hash
```
Record Type: CKUserProfile
Predicate: appleUserIdHash == "user_hash_here"
```

### Find Active Family Members
```
Record Type: CKMembership
Predicate: family == [family_reference] AND status == "active"
```

### Find Parent Admin
```
Record Type: CKMembership
Predicate: family == [family_reference] AND role == "parent_admin" AND status == "active"
```

## Performance Considerations

1. **Indexes**: All queryable fields have appropriate indexes for fast lookups
2. **Custom Zone**: Using custom zone enables atomic operations and better organization
3. **Subscriptions**: Real-time updates reduce the need for frequent polling
4. **Reference Relationships**: Proper cascade deletion maintains data integrity

## Security Notes

1. **Client-Side Validation**: App enforces business rules (e.g., one parent admin per family)
2. **Private Database**: All data is stored in user's private CloudKit database
3. **No PII in CloudKit**: Minimal personally identifiable information stored
4. **Secure References**: Using CloudKit references maintains data relationships securely

## Troubleshooting

### Common Issues
1. **Index Not Found**: Ensure all required indexes are created and deployed
2. **Subscription Failures**: Check that custom zone exists before creating subscriptions
3. **Reference Errors**: Verify that referenced records exist before creating relationships
4. **Quota Limits**: Monitor CloudKit usage to avoid quota exceeded errors

### Debugging Tools
1. Use CloudKit Console "Logs" to view operation details
2. Enable CloudKit logging in Xcode for detailed error messages
3. Test queries in CloudKit Console before implementing in app
4. Use CloudKit Dashboard to monitor usage and performance