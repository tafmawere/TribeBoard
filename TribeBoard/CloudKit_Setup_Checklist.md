# CloudKit Setup Checklist

This checklist ensures that all CloudKit schema and subscription components are properly configured for the TribeBoard Family Setup & Roles module.

## ✅ Pre-Setup Requirements

- [ ] Apple Developer Account with CloudKit access
- [ ] TribeBoard app configured with CloudKit container `iCloud.net.dataenvy.TribeBoard`
- [ ] Xcode project configured with CloudKit capability
- [ ] App entitlements include CloudKit and iCloud capabilities

## ✅ CloudKit Console Setup

### 1. Container Configuration
- [ ] Container `iCloud.net.dataenvy.TribeBoard` exists
- [ ] Development environment is active
- [ ] Production environment is configured (for release)

### 2. Record Types Creation

#### CKFamily Record Type
- [ ] Record type `CKFamily` created
- [ ] Fields configured:
  - [ ] `name` (String)
  - [ ] `code` (String, Indexed, Queryable)
  - [ ] `createdByUserId` (String, Indexed, Queryable)
  - [ ] `createdAt` (Date/Time, Sortable)
- [ ] Indexes created:
  - [ ] Family Code Index on `code` field (QUERYABLE)
  - [ ] Creator Index on `createdByUserId` field (QUERYABLE)

#### CKUserProfile Record Type
- [ ] Record type `CKUserProfile` created
- [ ] Fields configured:
  - [ ] `displayName` (String)
  - [ ] `appleUserIdHash` (String, Indexed, Queryable)
  - [ ] `avatarUrl` (String)
  - [ ] `createdAt` (Date/Time, Sortable)
- [ ] Indexes created:
  - [ ] Apple ID Hash Index on `appleUserIdHash` field (QUERYABLE)

#### CKMembership Record Type
- [ ] Record type `CKMembership` created
- [ ] Fields configured:
  - [ ] `role` (String, Indexed, Queryable)
  - [ ] `joinedAt` (Date/Time, Sortable)
  - [ ] `status` (String, Indexed, Queryable)
  - [ ] `lastRoleChangeAt` (Date/Time, Sortable)
  - [ ] `family` (Reference to CKFamily, Indexed, Queryable, Delete Self)
  - [ ] `user` (Reference to CKUserProfile, Indexed, Queryable, Delete Self)
- [ ] Indexes created:
  - [ ] Family Membership Index on `family` field (QUERYABLE)
  - [ ] User Membership Index on `user` field (QUERYABLE)
  - [ ] Active Membership Index on `family` + `status` fields (QUERYABLE)
  - [ ] Role Index on `role` field (QUERYABLE)

### 3. Security Configuration
- [ ] World access: No Access for all record types
- [ ] Authenticated access: Read/Write for all record types
- [ ] Custom security roles configured if needed

### 4. Schema Deployment
- [ ] Schema deployed to Development environment
- [ ] Schema tested in Development environment
- [ ] Schema deployed to Production environment (when ready)

## ✅ App Implementation

### 1. CloudKit Service Setup
- [ ] `CloudKitService` class implemented with subscription support
- [ ] Custom zone creation (`TribeBoardZone`) implemented
- [ ] Subscription setup methods implemented
- [ ] Remote notification handling implemented

### 2. App Configuration
- [ ] `AppDelegate` configured for remote notifications
- [ ] `TribeBoardApp` configured with CloudKit service
- [ ] Notification permissions requested
- [ ] Remote notification registration implemented

### 3. Schema Validation
- [ ] `CloudKitSchemaValidator` utility implemented
- [ ] Schema validation tests added
- [ ] Validation report functionality working

## ✅ Testing and Validation

### 1. Initial Setup Testing
- [ ] Run app and call `CloudKitService.performInitialSetup()`
- [ ] Verify custom zone `TribeBoardZone` is created
- [ ] Verify subscriptions are created:
  - [ ] `family-changes` subscription
  - [ ] `membership-changes` subscription
  - [ ] `userprofile-changes` subscription

### 2. Schema Validation Testing
- [ ] Run `cloudKitService.validateSchema()` and verify results
- [ ] Run `cloudKitService.printSchemaValidationReport()` and check output
- [ ] All validation issues resolved

### 3. Record Operations Testing
- [ ] Test Family record creation and querying
- [ ] Test UserProfile record creation and querying
- [ ] Test Membership record creation and querying
- [ ] Test record relationships and references

### 4. Subscription Testing
- [ ] Test real-time updates when records change
- [ ] Verify notification handling works correctly
- [ ] Test offline/online sync scenarios

## ✅ Common Queries Testing

Test these queries in CloudKit Console Data section:

### Find Family by Code
```
Record Type: CKFamily
Predicate: code == "TEST123"
```
- [ ] Query returns correct family record

### Find User by Apple ID Hash
```
Record Type: CKUserProfile
Predicate: appleUserIdHash == "test_hash"
```
- [ ] Query returns correct user profile

### Find Active Family Members
```
Record Type: CKMembership
Predicate: family == [family_reference] AND status == "active"
```
- [ ] Query returns active memberships only

### Find Parent Admin
```
Record Type: CKMembership
Predicate: family == [family_reference] AND role == "parent_admin" AND status == "active"
```
- [ ] Query returns parent admin membership

## ✅ Performance Verification

- [ ] Family code lookup is fast (< 1 second)
- [ ] User profile lookup is fast (< 1 second)
- [ ] Family member queries are fast (< 2 seconds)
- [ ] Real-time updates arrive within 5 seconds
- [ ] Batch operations complete efficiently

## ✅ Error Handling Testing

- [ ] Test with CloudKit unavailable
- [ ] Test with network connectivity issues
- [ ] Test with quota exceeded scenarios
- [ ] Test with invalid record data
- [ ] Test conflict resolution scenarios

## ✅ Security Testing

- [ ] Verify users can only access their own data
- [ ] Test with multiple user accounts
- [ ] Verify reference relationships maintain data integrity
- [ ] Test cascade deletion works correctly

## ✅ Production Readiness

- [ ] All tests pass in Development environment
- [ ] Schema deployed to Production environment
- [ ] App Store Connect configuration updated
- [ ] CloudKit usage monitoring set up
- [ ] Error logging and monitoring configured

## 🚨 Troubleshooting

If any checklist item fails, refer to:

1. **CloudKit_Schema_Setup.md** - Detailed setup instructions
2. **CloudKitService.swift** - Implementation details
3. **CloudKitSchemaValidator.swift** - Validation utilities
4. CloudKit Console Logs - For operation details
5. Xcode CloudKit logs - For client-side debugging

## 📝 Notes

- Complete Development environment testing before Production deployment
- Keep CloudKit Console and app implementation in sync
- Monitor CloudKit usage to avoid quota limits
- Test thoroughly with multiple devices and user accounts
- Document any custom configurations or workarounds