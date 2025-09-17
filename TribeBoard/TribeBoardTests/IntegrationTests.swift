import XCTest
import SwiftData
@testable import TribeBoard

/// Integration tests for complete user flows
@MainActor
final class IntegrationTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var dataService: DataService!
    var authService: AuthService!
    var cloudKitService: CloudKitService!
    var qrCodeService: QRCodeService!
    var codeGenerator: CodeGenerator!
    var keychainService: KeychainService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory container for testing
        modelContainer = try ModelContainerConfiguration.createInMemory()
        dataService = DataService(modelContext: modelContainer.mainContext)
        keychainService = KeychainService()
        authService = AuthService(keychainService: keychainService, dataService: dataService)
        cloudKitService = CloudKitService(containerIdentifier: "iCloud.net.dataenvy.TribeBoard.test")
        qrCodeService = QRCodeService()
        codeGenerator = CodeGenerator()
        
        // Clean up any existing test data
        try? keychainService.clearAll()
    }
    
    override func tearDown() async throws {
        try? keychainService.clearAll()
        modelContainer = nil
        dataService = nil
        authService = nil
        cloudKitService = nil
        qrCodeService = nil
        codeGenerator = nil
        keychainService = nil
        try await super.tearDown()
    }
    
    // MARK: - Complete Family Creation Flow
    
    func testCompleteFamilyCreationFlow() async throws {
        // Step 1: Create user profile (simulating authentication)
        let userProfile = try dataService.createUserProfile(
            displayName: "John Doe",
            appleUserIdHash: "test_hash_123"
        )
        
        // Step 2: Generate unique family code
        let familyCode = try await codeGenerator.generateUniqueCode { code in
            // Check if code exists in local storage
            do {
                let existingFamilies = try dataService.fetchAllFamilies()
                return !existingFamilies.contains { $0.code == code }
            } catch {
                return true // If fetch fails, assume code is unique
            }
        }
        
        // Step 3: Create family
        let family = try dataService.createFamily(
            name: "Doe Family",
            code: familyCode,
            createdByUserId: userProfile.id
        )
        
        // Step 4: Create membership for creator (Parent Admin)
        let membership = try dataService.createMembership(
            family: family,
            user: userProfile,
            role: .parentAdmin
        )
        
        // Step 5: Generate QR code
        let qrCodeImage = qrCodeService.generateStyledFamilyQRCode(familyCode: familyCode)
        
        // Verify complete flow
        XCTAssertEqual(family.name, "Doe Family")
        XCTAssertEqual(family.code, familyCode)
        XCTAssertEqual(membership.role, .parentAdmin)
        XCTAssertEqual(membership.user?.id, userProfile.id)
        XCTAssertEqual(membership.family?.id, family.id)
        XCTAssertNotNil(qrCodeImage)
        XCTAssertTrue(family.isFullyValid)
        XCTAssertTrue(membership.isFullyValid)
    }
    
    // MARK: - Complete Family Joining Flow
    
    func testCompleteFamilyJoiningFlow() async throws {
        // Setup: Create existing family
        let creatorProfile = try dataService.createUserProfile(
            displayName: "Creator",
            appleUserIdHash: "creator_hash"
        )
        
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: creatorProfile.id
        )
        
        let creatorMembership = try dataService.createMembership(
            family: family,
            user: creatorProfile,
            role: .parentAdmin
        )
        
        // Step 1: Create joining user profile
        let joiningUser = try dataService.createUserProfile(
            displayName: "Jane Smith",
            appleUserIdHash: "jane_hash"
        )
        
        // Step 2: Search for family by code
        let foundFamilies = try dataService.fetchFamilies(byCode: "TEST123")
        XCTAssertEqual(foundFamilies.count, 1)
        let foundFamily = foundFamilies.first!
        
        // Step 3: Validate family code
        let codeValidation = Validation.validateFamilyCode("TEST123")
        XCTAssertTrue(codeValidation.isValid)
        
        // Step 4: Create membership for joining user
        let joiningMembership = try dataService.createMembership(
            family: foundFamily,
            user: joiningUser,
            role: .adult
        )
        
        // Step 5: Verify family now has 2 members
        let allMembers = try dataService.fetchActiveMembers(forFamily: foundFamily)
        XCTAssertEqual(allMembers.count, 2)
        
        // Verify joining flow
        XCTAssertEqual(joiningMembership.role, .adult)
        XCTAssertEqual(joiningMembership.user?.id, joiningUser.id)
        XCTAssertEqual(joiningMembership.family?.id, foundFamily.id)
        XCTAssertTrue(joiningMembership.isActive)
        
        // Verify family structure
        let parentAdmin = allMembers.first { $0.role == .parentAdmin }
        XCTAssertNotNil(parentAdmin)
        XCTAssertEqual(parentAdmin?.user?.id, creatorProfile.id)
        
        let adultMember = allMembers.first { $0.role == .adult }
        XCTAssertNotNil(adultMember)
        XCTAssertEqual(adultMember?.user?.id, joiningUser.id)
    }
    
    // MARK: - Role Management Flow
    
    func testCompleteRoleManagementFlow() async throws {
        // Setup: Create family with multiple members
        let parentUser = try dataService.createUserProfile(
            displayName: "Parent",
            appleUserIdHash: "parent_hash"
        )
        
        let adultUser = try dataService.createUserProfile(
            displayName: "Adult",
            appleUserIdHash: "adult_hash"
        )
        
        let kidUser = try dataService.createUserProfile(
            displayName: "Kid",
            appleUserIdHash: "kid_hash"
        )
        
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "FAMILY1",
            createdByUserId: parentUser.id
        )
        
        let parentMembership = try dataService.createMembership(
            family: family,
            user: parentUser,
            role: .parentAdmin
        )
        
        let adultMembership = try dataService.createMembership(
            family: family,
            user: adultUser,
            role: .adult
        )
        
        let kidMembership = try dataService.createMembership(
            family: family,
            user: kidUser,
            role: .kid
        )
        
        // Step 1: Verify initial roles
        XCTAssertEqual(parentMembership.role, .parentAdmin)
        XCTAssertEqual(adultMembership.role, .adult)
        XCTAssertEqual(kidMembership.role, .kid)
        
        // Step 2: Change adult to visitor
        try dataService.updateMembershipRole(adultMembership, to: .visitor)
        XCTAssertEqual(adultMembership.role, .visitor)
        
        // Step 3: Try to change adult to parent admin (should fail)
        XCTAssertThrowsError(try dataService.updateMembershipRole(adultMembership, to: .parentAdmin)) { error in
            if case DataServiceError.validationFailed(let errors) = error {
                XCTAssertTrue(errors.contains("Parent Admin already exists"))
            } else {
                XCTFail("Expected validation error")
            }
        }
        
        // Step 4: Remove a member
        try dataService.removeMember(kidMembership)
        XCTAssertEqual(kidMembership.status, .removed)
        
        // Step 5: Verify active members count
        let activeMembers = try dataService.fetchActiveMembers(forFamily: family)
        XCTAssertEqual(activeMembers.count, 2) // Parent and Adult (now Visitor)
        
        // Step 6: Verify family still has parent admin
        XCTAssertTrue(try dataService.familyHasParentAdmin(family))
    }
    
    // MARK: - Data Validation Flow
    
    func testCompleteDataValidationFlow() throws {
        // Test family validation
        let familyValidation = try dataService.validateFamily(name: "Valid Family", code: "VALID1")
        XCTAssertTrue(familyValidation.isValid)
        
        let invalidFamilyValidation = try dataService.validateFamily(name: "", code: "12")
        XCTAssertFalse(invalidFamilyValidation.isValid)
        
        // Test user profile validation
        let userValidation = dataService.validateUserProfile(
            displayName: "John Doe",
            appleUserIdHash: "valid_hash_123"
        )
        XCTAssertTrue(userValidation.isValid)
        
        let invalidUserValidation = dataService.validateUserProfile(
            displayName: "",
            appleUserIdHash: ""
        )
        XCTAssertFalse(invalidUserValidation.isValid)
        
        // Test code format validation
        XCTAssertTrue(dataService.isValidFamilyCodeFormat("ABC123"))
        XCTAssertFalse(dataService.isValidFamilyCodeFormat("ABC-123"))
        
        // Test code formatting
        let formattedCode = Validation.formatFamilyCode("abc-123 def")
        XCTAssertEqual(formattedCode, "ABC123DE")
    }
    
    // MARK: - QR Code Integration Flow
    
    func testQRCodeIntegrationFlow() {
        let familyCode = "QR123"
        
        // Step 1: Generate QR code
        let qrImage = qrCodeService.generateQRCode(from: familyCode)
        XCTAssertNotNil(qrImage)
        
        // Step 2: Generate styled QR code
        let styledQRImage = qrCodeService.generateStyledFamilyQRCode(familyCode: familyCode)
        XCTAssertNotNil(styledQRImage)
        
        // Step 3: Verify QR code properties
        XCTAssertEqual(qrImage?.size, CGSize(width: 200, height: 200))
        XCTAssertEqual(styledQRImage?.size, CGSize(width: 340, height: 380))
        
        // Note: QR code scanning tested separately due to simulator limitations
    }
    
    // MARK: - Error Handling Integration
    
    func testErrorHandlingIntegration() throws {
        // Test duplicate family code
        let user = try dataService.createUserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash"
        )
        
        _ = try dataService.createFamily(
            name: "Family 1",
            code: "DUPLICATE",
            createdByUserId: user.id
        )
        
        XCTAssertThrowsError(try dataService.createFamily(
            name: "Family 2",
            code: "DUPLICATE",
            createdByUserId: user.id
        )) { error in
            if case DataServiceError.validationFailed(let errors) = error {
                XCTAssertTrue(errors.contains("Family code already exists"))
            } else {
                XCTFail("Expected validation error")
            }
        }
        
        // Test duplicate membership
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST456",
            createdByUserId: user.id
        )
        
        _ = try dataService.createMembership(
            family: family,
            user: user,
            role: .adult
        )
        
        XCTAssertThrowsError(try dataService.createMembership(
            family: family,
            user: user,
            role: .kid
        )) { error in
            if case DataServiceError.constraintViolation(let message) = error {
                XCTAssertTrue(message.contains("already a member"))
            } else {
                XCTFail("Expected constraint violation error")
            }
        }
    }
    
    // MARK: - Performance Integration Tests
    
    func testPerformanceIntegration() throws {
        measure {
            do {
                // Create multiple families and users
                for i in 0..<10 {
                    let user = try dataService.createUserProfile(
                        displayName: "User \(i)",
                        appleUserIdHash: "hash_\(i)"
                    )
                    
                    let family = try dataService.createFamily(
                        name: "Family \(i)",
                        code: "FAM\(String(format: "%03d", i))",
                        createdByUserId: user.id
                    )
                    
                    _ = try dataService.createMembership(
                        family: family,
                        user: user,
                        role: .parentAdmin
                    )
                }
                
                // Fetch all families
                let allFamilies = try dataService.fetchAllFamilies()
                XCTAssertEqual(allFamilies.count, 10)
                
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Keychain Integration Tests
    
    func testKeychainIntegration() throws {
        let testHash = "integration_test_hash"
        let testFamilyId = UUID()
        
        // Store data
        try keychainService.storeAppleUserIdHash(testHash)
        try keychainService.storeFamilyId(testFamilyId)
        
        // Retrieve data
        let retrievedHash = try keychainService.retrieveAppleUserIdHash()
        let retrievedFamilyId = try keychainService.retrieveFamilyId()
        
        XCTAssertEqual(retrievedHash, testHash)
        XCTAssertEqual(retrievedFamilyId, testFamilyId)
        
        // Clear data
        try keychainService.clearAll()
        
        let clearedHash = try keychainService.retrieveAppleUserIdHash()
        let clearedFamilyId = try keychainService.retrieveFamilyId()
        
        XCTAssertNil(clearedHash)
        XCTAssertNil(clearedFamilyId)
    }
}

// MARK: - Helper Extensions

extension DataService {
    func fetchAllFamilies() throws -> [Family] {
        let descriptor = FetchDescriptor<Family>()
        return try modelContext.fetch(descriptor)
    }
    
    func fetchFamilies(byCode code: String) throws -> [Family] {
        let descriptor = FetchDescriptor<Family>(
            predicate: #Predicate { $0.code == code }
        )
        return try modelContext.fetch(descriptor)
    }
}