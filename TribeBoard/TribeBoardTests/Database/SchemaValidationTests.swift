import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for model relationship validation and schema integrity
/// Requirements: 2.4, 5.1, 5.2
@MainActor
final class SchemaValidationTests: DatabaseTestBase {
    
    // MARK: - Schema Entity Presence Tests
    
    /// Test that all expected entities are present in schema
    /// Requirements: 2.4
    func testAllExpectedEntitiesPresent() throws {
        print("🧪 Testing that all expected entities are present in schema...")
        
        // Create schema to validate entity presence
        let schema = Schema([
            Family.self,
            UserProfile.self,
            Membership.self
        ])
        
        // Verify schema was created successfully
        XCTAssertNotNil(schema, "Schema should be created successfully")
        
        // Check that all expected entities are present
        let entityNames = schema.entities.map { $0.name }
        let expectedEntities = ["Family", "UserProfile", "Membership"]
        
        for expectedEntity in expectedEntities {
            XCTAssertTrue(
                entityNames.contains(expectedEntity),
                "Schema should contain \(expectedEntity) entity. Found entities: \(entityNames)"
            )
        }
        
        // Verify we have exactly the expected number of entities
        XCTAssertEqual(
            schema.entities.count,
            expectedEntities.count,
            "Schema should contain exactly \(expectedEntities.count) entities, found \(schema.entities.count)"
        )
        
        print("✅ All expected entities present in schema: \(entityNames)")
    }
    
    /// Test schema compilation with ModelContainer
    /// Requirements: 2.4
    func testSchemaCompilationWithContainer() throws {
        print("🧪 Testing schema compilation with ModelContainer...")
        
        // Test that schema compiles successfully with in-memory container
        let container = try ModelContainerConfiguration.createInMemory()
        XCTAssertNotNil(container, "Container should be created with valid schema")
        
        // Test that context can be created
        let context = container.mainContext
        XCTAssertNotNil(context, "Context should be created from valid schema")
        
        // Test that all model types can be used
        let family = Family(name: "Schema Test", code: "SCH123", createdByUserId: UUID())
        let user = UserProfile(displayName: "Schema User", appleUserIdHash: "schema_hash")
        let membership = Membership(family: family, user: user, role: .adult)
        
        // These operations should not throw if schema is valid
        context.insert(family)
        context.insert(user)
        context.insert(membership)
        
        // Verify entities can be fetched (validates schema integrity)
        let familyDescriptor = FetchDescriptor<Family>()
        let families = try context.fetch(familyDescriptor)
        XCTAssertGreaterThanOrEqual(families.count, 1, "Schema should support Family entity operations")
        
        let userDescriptor = FetchDescriptor<UserProfile>()
        let users = try context.fetch(userDescriptor)
        XCTAssertGreaterThanOrEqual(users.count, 1, "Schema should support UserProfile entity operations")
        
        let membershipDescriptor = FetchDescriptor<Membership>()
        let memberships = try context.fetch(membershipDescriptor)
        XCTAssertGreaterThanOrEqual(memberships.count, 1, "Schema should support Membership entity operations")
        
        print("✅ Schema compilation and basic operations successful")
    }
    
    // MARK: - Relationship Configuration Tests
    
    /// Test that all relationships are properly configured with correct inverse relationships
    /// Requirements: 5.1, 5.2
    func testRelationshipConfiguration() throws {
        print("🧪 Testing relationship configuration...")
        
        // Create test data to validate relationships
        let testUser = try createTestUser(displayName: "Relationship User", appleUserIdHash: "rel_hash")
        let testFamily = try createTestFamily(name: "Relationship Family", code: "REL123", createdByUserId: testUser.id)
        let testMembership = try createTestMembership(family: testFamily, user: testUser, role: .parentAdmin)
        
        // Test Family -> Membership relationship
        XCTAssertNotNil(testFamily.memberships, "Family should have memberships relationship")
        XCTAssertTrue(
            testFamily.memberships?.contains { $0.id == testMembership.id } ?? false,
            "Family memberships should contain the created membership"
        )
        
        // Test UserProfile -> Membership relationship
        XCTAssertNotNil(testUser.memberships, "UserProfile should have memberships relationship")
        XCTAssertTrue(
            testUser.memberships?.contains { $0.id == testMembership.id } ?? false,
            "User memberships should contain the created membership"
        )
        
        // Test Membership -> Family relationship
        XCTAssertNotNil(testMembership.family, "Membership should have family relationship")
        XCTAssertEqual(testMembership.family?.id, testFamily.id, "Membership family should reference correct family")
        
        // Test Membership -> User relationship
        XCTAssertNotNil(testMembership.user, "Membership should have user relationship")
        XCTAssertEqual(testMembership.user?.id, testUser.id, "Membership user should reference correct user")
        
        print("✅ All relationship configurations validated")
    }
    
    /// Test inverse relationship integrity
    /// Requirements: 5.1, 5.2
    func testInverseRelationshipIntegrity() throws {
        print("🧪 Testing inverse relationship integrity...")
        
        // Create test entities
        let user1 = try createTestUser(displayName: "Inverse User 1", appleUserIdHash: "inv_hash_1")
        let user2 = try createTestUser(displayName: "Inverse User 2", appleUserIdHash: "inv_hash_2")
        let family = try createTestFamily(name: "Inverse Family", code: "INV123", createdByUserId: user1.id)
        
        // Create memberships
        let membership1 = try createTestMembership(family: family, user: user1, role: .parentAdmin)
        let membership2 = try createTestMembership(family: family, user: user2, role: .kid)
        
        // Test that family contains both memberships
        let familyMembershipIds = family.memberships?.map { $0.id } ?? []
        XCTAssertTrue(
            familyMembershipIds.contains(membership1.id),
            "Family should contain membership1 in inverse relationship"
        )
        XCTAssertTrue(
            familyMembershipIds.contains(membership2.id),
            "Family should contain membership2 in inverse relationship"
        )
        
        // Test that users contain their respective memberships
        let user1MembershipIds = user1.memberships?.map { $0.id } ?? []
        XCTAssertTrue(
            user1MembershipIds.contains(membership1.id),
            "User1 should contain membership1 in inverse relationship"
        )
        XCTAssertFalse(
            user1MembershipIds.contains(membership2.id),
            "User1 should not contain membership2 in inverse relationship"
        )
        
        let user2MembershipIds = user2.memberships?.map { $0.id } ?? []
        XCTAssertTrue(
            user2MembershipIds.contains(membership2.id),
            "User2 should contain membership2 in inverse relationship"
        )
        XCTAssertFalse(
            user2MembershipIds.contains(membership1.id),
            "User2 should not contain membership1 in inverse relationship"
        )
        
        // Test computed properties that depend on relationships
        XCTAssertEqual(family.activeMembers.count, 2, "Family should have 2 active members")
        XCTAssertTrue(family.hasParentAdmin, "Family should have a parent admin")
        XCTAssertEqual(user1.activeMemberships.count, 1, "User1 should have 1 active membership")
        XCTAssertEqual(user2.activeMemberships.count, 1, "User2 should have 1 active membership")
        
        print("✅ Inverse relationship integrity validated")
    }
    
    /// Test relationship updates and consistency
    /// Requirements: 5.1, 5.2
    func testRelationshipUpdateConsistency() throws {
        print("🧪 Testing relationship update consistency...")
        
        // Create initial test data
        let user = try createTestUser(displayName: "Update User", appleUserIdHash: "update_hash")
        let family1 = try createTestFamily(name: "Update Family 1", code: "UPD123", createdByUserId: user.id)
        let family2 = try createTestFamily(name: "Update Family 2", code: "UPD456", createdByUserId: user.id)
        
        let membership = try createTestMembership(family: family1, user: user, role: .adult)
        
        // Verify initial state
        XCTAssertEqual(membership.family?.id, family1.id, "Membership should initially reference family1")
        XCTAssertTrue(
            family1.memberships?.contains { $0.id == membership.id } ?? false,
            "Family1 should initially contain the membership"
        )
        XCTAssertFalse(
            family2.memberships?.contains { $0.id == membership.id } ?? false,
            "Family2 should not initially contain the membership"
        )
        
        // Update relationship
        membership.family = family2
        try saveContext()
        
        // Verify relationship update consistency
        XCTAssertEqual(membership.family?.id, family2.id, "Membership should now reference family2")
        
        // Refresh entities from context to check inverse relationships
        let refreshedFamily1 = try fetchAllRecords(Family.self).first { $0.id == family1.id }
        let refreshedFamily2 = try fetchAllRecords(Family.self).first { $0.id == family2.id }
        
        XCTAssertFalse(
            refreshedFamily1?.memberships?.contains { $0.id == membership.id } ?? true,
            "Family1 should no longer contain the membership after update"
        )
        XCTAssertTrue(
            refreshedFamily2?.memberships?.contains { $0.id == membership.id } ?? false,
            "Family2 should now contain the membership after update"
        )
        
        print("✅ Relationship update consistency validated")
    }
    
    // MARK: - Cascade Delete Rule Tests
    
    /// Test that cascade delete rules are properly set up
    /// Requirements: 5.1, 5.2
    func testCascadeDeleteRules() throws {
        print("🧪 Testing cascade delete rules...")
        
        // Create test data with relationships
        let user = try createTestUser(displayName: "Cascade User", appleUserIdHash: "cascade_hash")
        let family = try createTestFamily(name: "Cascade Family", code: "CAS123", createdByUserId: user.id)
        let membership = try createTestMembership(family: family, user: user, role: .parentAdmin)
        
        let membershipId = membership.id
        
        // Verify initial state
        try assertRecordCount(Family.self, expectedCount: 1)
        try assertRecordCount(UserProfile.self, expectedCount: 1)
        try assertRecordCount(Membership.self, expectedCount: 1)
        
        // Test cascade delete when family is deleted
        testContext.delete(family)
        try saveContext()
        
        // Verify cascade delete worked
        try assertRecordCount(Family.self, expectedCount: 0)
        try assertRecordCount(UserProfile.self, expectedCount: 1) // User should remain
        try assertRecordCount(Membership.self, expectedCount: 0) // Membership should be cascade deleted
        
        // Verify the specific membership was deleted
        let remainingMemberships = try fetchAllRecords(Membership.self)
        XCTAssertFalse(
            remainingMemberships.contains { $0.id == membershipId },
            "Membership should be cascade deleted when family is deleted"
        )
        
        print("✅ Cascade delete rules for family deletion validated")
    }
    
    /// Test cascade delete when user is deleted
    /// Requirements: 5.1, 5.2
    func testCascadeDeleteUserDeletion() throws {
        print("🧪 Testing cascade delete when user is deleted...")
        
        // Create test data
        let user = try createTestUser(displayName: "Delete User", appleUserIdHash: "delete_hash")
        let family = try createTestFamily(name: "Delete Family", code: "DEL123", createdByUserId: user.id)
        let membership = try createTestMembership(family: family, user: user, role: .adult)
        
        let membershipId = membership.id
        
        // Verify initial state
        try assertRecordCount(Family.self, expectedCount: 1)
        try assertRecordCount(UserProfile.self, expectedCount: 1)
        try assertRecordCount(Membership.self, expectedCount: 1)
        
        // Test cascade delete when user is deleted
        testContext.delete(user)
        try saveContext()
        
        // Verify cascade delete worked
        try assertRecordCount(Family.self, expectedCount: 1) // Family should remain
        try assertRecordCount(UserProfile.self, expectedCount: 0)
        try assertRecordCount(Membership.self, expectedCount: 0) // Membership should be cascade deleted
        
        // Verify the specific membership was deleted
        let remainingMemberships = try fetchAllRecords(Membership.self)
        XCTAssertFalse(
            remainingMemberships.contains { $0.id == membershipId },
            "Membership should be cascade deleted when user is deleted"
        )
        
        print("✅ Cascade delete rules for user deletion validated")
    }
    
    /// Test that membership deletion doesn't cascade to family or user
    /// Requirements: 5.1, 5.2
    func testMembershipDeletionNoCascade() throws {
        print("🧪 Testing that membership deletion doesn't cascade...")
        
        // Create test data
        let user = try createTestUser(displayName: "No Cascade User", appleUserIdHash: "nocascade_hash")
        let family = try createTestFamily(name: "No Cascade Family", code: "NOC123", createdByUserId: user.id)
        let membership = try createTestMembership(family: family, user: user, role: .kid)
        
        let userId = user.id
        let familyId = family.id
        
        // Verify initial state
        try assertRecordCount(Family.self, expectedCount: 1)
        try assertRecordCount(UserProfile.self, expectedCount: 1)
        try assertRecordCount(Membership.self, expectedCount: 1)
        
        // Delete membership only
        testContext.delete(membership)
        try saveContext()
        
        // Verify family and user remain
        try assertRecordCount(Family.self, expectedCount: 1)
        try assertRecordCount(UserProfile.self, expectedCount: 1)
        try assertRecordCount(Membership.self, expectedCount: 0)
        
        // Verify specific entities remain
        let remainingFamilies = try fetchAllRecords(Family.self)
        XCTAssertTrue(
            remainingFamilies.contains { $0.id == familyId },
            "Family should remain when membership is deleted"
        )
        
        let remainingUsers = try fetchAllRecords(UserProfile.self)
        XCTAssertTrue(
            remainingUsers.contains { $0.id == userId },
            "User should remain when membership is deleted"
        )
        
        print("✅ Membership deletion without cascade validated")
    }
    
    // MARK: - Schema Compilation Tests
    
    /// Validate that schema compilation succeeds for all model combinations
    /// Requirements: 2.4
    func testSchemaCompilationAllModelCombinations() throws {
        print("🧪 Testing schema compilation for all model combinations...")
        
        // Test individual model schemas
        let familySchema = Schema([Family.self])
        XCTAssertNotNil(familySchema, "Family-only schema should compile")
        XCTAssertEqual(familySchema.entities.count, 1, "Family-only schema should have 1 entity")
        
        let userSchema = Schema([UserProfile.self])
        XCTAssertNotNil(userSchema, "UserProfile-only schema should compile")
        XCTAssertEqual(userSchema.entities.count, 1, "UserProfile-only schema should have 1 entity")
        
        let membershipSchema = Schema([Membership.self])
        XCTAssertNotNil(membershipSchema, "Membership-only schema should compile")
        XCTAssertEqual(membershipSchema.entities.count, 1, "Membership-only schema should have 1 entity")
        
        // Test two-model combinations
        let familyUserSchema = Schema([Family.self, UserProfile.self])
        XCTAssertNotNil(familyUserSchema, "Family+UserProfile schema should compile")
        XCTAssertEqual(familyUserSchema.entities.count, 2, "Family+UserProfile schema should have 2 entities")
        
        let familyMembershipSchema = Schema([Family.self, Membership.self])
        XCTAssertNotNil(familyMembershipSchema, "Family+Membership schema should compile")
        XCTAssertEqual(familyMembershipSchema.entities.count, 2, "Family+Membership schema should have 2 entities")
        
        let userMembershipSchema = Schema([UserProfile.self, Membership.self])
        XCTAssertNotNil(userMembershipSchema, "UserProfile+Membership schema should compile")
        XCTAssertEqual(userMembershipSchema.entities.count, 2, "UserProfile+Membership schema should have 2 entities")
        
        // Test full schema
        let fullSchema = Schema([Family.self, UserProfile.self, Membership.self])
        XCTAssertNotNil(fullSchema, "Full schema should compile")
        XCTAssertEqual(fullSchema.entities.count, 3, "Full schema should have 3 entities")
        
        print("✅ All schema combinations compile successfully")
    }
    
    /// Test schema validation with ModelContainer creation
    /// Requirements: 2.4
    func testSchemaValidationWithContainerCreation() throws {
        print("🧪 Testing schema validation with container creation...")
        
        // Test that ModelContainerConfiguration.validateSchema() works
        do {
            try ModelContainerConfiguration.validateSchema()
            print("   ✅ Schema validation passed")
        } catch {
            XCTFail("Schema validation should pass for valid models: \(error)")
        }
        
        // Test that validated schema can create containers
        let inMemoryContainer = try ModelContainerConfiguration.createInMemory()
        XCTAssertNotNil(inMemoryContainer, "Validated schema should create in-memory container")
        
        let fallbackContainer = ModelContainerConfiguration.createWithFallback()
        XCTAssertNotNil(fallbackContainer, "Validated schema should create fallback container")
        
        // Test that containers are functional
        let context = inMemoryContainer.mainContext
        let testFamily = Family(name: "Validation Test", code: "VAL123", createdByUserId: UUID())
        context.insert(testFamily)
        
        let descriptor = FetchDescriptor<Family>()
        let families = try context.fetch(descriptor)
        XCTAssertGreaterThanOrEqual(families.count, 1, "Validated schema should support operations")
        
        print("✅ Schema validation with container creation successful")
    }
    
    // MARK: - Property and Attribute Tests
    
    /// Test model property configurations
    /// Requirements: 2.4
    func testModelPropertyConfigurations() throws {
        print("🧪 Testing model property configurations...")
        
        let schema = Schema([Family.self, UserProfile.self, Membership.self])
        
        // Test Family entity properties
        let familyEntity = schema.entities.first { $0.name == "Family" }
        XCTAssertNotNil(familyEntity, "Family entity should exist in schema")
        
        let familyPropertyNames = familyEntity?.properties.map { $0.name } ?? []
        let expectedFamilyProperties = ["id", "name", "code", "createdByUserId", "createdAt", "ckRecordID", "lastSyncDate", "needsSync", "memberships"]
        
        for expectedProperty in expectedFamilyProperties {
            XCTAssertTrue(
                familyPropertyNames.contains(expectedProperty),
                "Family entity should have \(expectedProperty) property. Found: \(familyPropertyNames)"
            )
        }
        
        // Test UserProfile entity properties
        let userEntity = schema.entities.first { $0.name == "UserProfile" }
        XCTAssertNotNil(userEntity, "UserProfile entity should exist in schema")
        
        let userPropertyNames = userEntity?.properties.map { $0.name } ?? []
        let expectedUserProperties = ["id", "displayName", "appleUserIdHash", "avatarUrl", "createdAt", "ckRecordID", "lastSyncDate", "needsSync", "memberships"]
        
        for expectedProperty in expectedUserProperties {
            XCTAssertTrue(
                userPropertyNames.contains(expectedProperty),
                "UserProfile entity should have \(expectedProperty) property. Found: \(userPropertyNames)"
            )
        }
        
        // Test Membership entity properties
        let membershipEntity = schema.entities.first { $0.name == "Membership" }
        XCTAssertNotNil(membershipEntity, "Membership entity should exist in schema")
        
        let membershipPropertyNames = membershipEntity?.properties.map { $0.name } ?? []
        let expectedMembershipProperties = ["id", "role", "joinedAt", "status", "lastRoleChangeAt", "ckRecordID", "lastSyncDate", "needsSync", "family", "user"]
        
        for expectedProperty in expectedMembershipProperties {
            XCTAssertTrue(
                membershipPropertyNames.contains(expectedProperty),
                "Membership entity should have \(expectedProperty) property. Found: \(membershipPropertyNames)"
            )
        }
        
        print("✅ Model property configurations validated")
    }
    
    /// Test enum property handling in schema
    /// Requirements: 2.4
    func testEnumPropertyHandling() throws {
        print("🧪 Testing enum property handling in schema...")
        
        // Create test data with enum properties
        let user = try createTestUser(displayName: "Enum User", appleUserIdHash: "enum_hash")
        let family = try createTestFamily(name: "Enum Family", code: "ENUM12", createdByUserId: user.id)
        
        // Test all Role enum values
        let parentAdminMembership = try createTestMembership(family: family, user: user, role: .parentAdmin)
        XCTAssertEqual(parentAdminMembership.role, .parentAdmin, "Schema should handle parentAdmin role")
        
        // Create additional users for other roles
        let adultUser = try createTestUser(displayName: "Adult User", appleUserIdHash: "adult_hash")
        let adultMembership = try createTestMembership(family: family, user: adultUser, role: .adult)
        XCTAssertEqual(adultMembership.role, .adult, "Schema should handle adult role")
        
        let kidUser = try createTestUser(displayName: "Kid User", appleUserIdHash: "kid_hash")
        let kidMembership = try createTestMembership(family: family, user: kidUser, role: .kid)
        XCTAssertEqual(kidMembership.role, .kid, "Schema should handle kid role")
        
        let visitorUser = try createTestUser(displayName: "Visitor User", appleUserIdHash: "visitor_hash")
        let visitorMembership = try createTestMembership(family: family, user: visitorUser, role: .visitor)
        XCTAssertEqual(visitorMembership.role, .visitor, "Schema should handle visitor role")
        
        // Test MembershipStatus enum values
        XCTAssertEqual(parentAdminMembership.status, .active, "Schema should handle active status")
        
        // Test status changes
        parentAdminMembership.status = .invited
        try saveContext()
        XCTAssertEqual(parentAdminMembership.status, .invited, "Schema should handle status changes")
        
        parentAdminMembership.status = .removed
        try saveContext()
        XCTAssertEqual(parentAdminMembership.status, .removed, "Schema should handle removed status")
        
        // Verify enum values persist correctly
        let fetchedMemberships = try fetchAllRecords(Membership.self)
        let roles = fetchedMemberships.map { $0.role }
        XCTAssertTrue(roles.contains(.parentAdmin), "Schema should persist parentAdmin role")
        XCTAssertTrue(roles.contains(.adult), "Schema should persist adult role")
        XCTAssertTrue(roles.contains(.kid), "Schema should persist kid role")
        XCTAssertTrue(roles.contains(.visitor), "Schema should persist visitor role")
        
        print("✅ Enum property handling validated")
    }
    
    // MARK: - CloudKit Schema Compatibility Tests
    
    /// Test CloudKit schema compatibility
    /// Requirements: 2.4
    func testCloudKitSchemaCompatibility() throws {
        print("🧪 Testing CloudKit schema compatibility...")
        
        // Create test entities
        let user = try createTestUser(displayName: "CloudKit User", appleUserIdHash: "ck_hash")
        let family = try createTestFamily(name: "CloudKit Family", code: "CK123", createdByUserId: user.id)
        let membership = try createTestMembership(family: family, user: user, role: .adult)
        
        // Test CloudKit record conversion
        do {
            let familyRecord = try family.toCKRecord()
            XCTAssertEqual(familyRecord.recordType, CKRecordType.family, "Family should convert to correct CloudKit record type")
            XCTAssertEqual(familyRecord[CKFieldName.familyName] as? String, "CloudKit Family", "Family record should contain correct name")
            XCTAssertEqual(familyRecord[CKFieldName.familyCode] as? String, "CK123", "Family record should contain correct code")
            
            let userRecord = try user.toCKRecord()
            XCTAssertEqual(userRecord.recordType, CKRecordType.userProfile, "User should convert to correct CloudKit record type")
            XCTAssertEqual(userRecord[CKFieldName.userDisplayName] as? String, "CloudKit User", "User record should contain correct display name")
            XCTAssertEqual(userRecord[CKFieldName.userAppleUserIdHash] as? String, "ck_hash", "User record should contain correct hash")
            
            let membershipRecord = try membership.toCKRecord()
            XCTAssertEqual(membershipRecord.recordType, CKRecordType.membership, "Membership should convert to correct CloudKit record type")
            XCTAssertEqual(membershipRecord[CKFieldName.membershipRole] as? String, Role.adult.rawValue, "Membership record should contain correct role")
            XCTAssertEqual(membershipRecord[CKFieldName.membershipStatus] as? String, MembershipStatus.active.rawValue, "Membership record should contain correct status")
            
            print("✅ CloudKit record conversion successful")
            
        } catch {
            XCTFail("CloudKit record conversion should work with valid schema: \(error)")
        }
        
        print("✅ CloudKit schema compatibility validated")
    }
}