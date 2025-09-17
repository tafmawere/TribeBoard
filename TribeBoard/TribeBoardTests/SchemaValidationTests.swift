import XCTest
import SwiftData
@testable import TribeBoard

@MainActor
final class SchemaValidationTests: XCTestCase {
    
    func testSchemaValidationSuccess() throws {
        // Test that schema validation passes for valid models
        print("🧪 Testing SwiftData schema validation...")
        
        // Test that schema validation passes for valid models
        do {
            try ModelContainerConfiguration.validateSchema()
            print("✅ Schema validation passed successfully")
        } catch {
            XCTFail("Schema validation should pass for valid models: \(error)")
        }
    }
    
    func testSchemaValidationWithContainerCreation() throws {
        // Test that schema validation works with actual container creation
        print("🧪 Testing schema validation with container creation...")
        
        // Create an in-memory container which should work
        let container = try ModelContainerConfiguration.createInMemory()
        XCTAssertNotNil(container)
        
        // Test basic operations to ensure schema is valid
        let context = container.mainContext
        
        let testFamily = Family(
            name: "Schema Test Family",
            code: "SCH123",
            createdByUserId: UUID()
        )
        
        context.insert(testFamily)
        
        let descriptor = FetchDescriptor<Family>()
        let families = try context.fetch(descriptor)
        let foundFamily = families.first { $0.name == "Schema Test Family" }
        XCTAssertNotNil(foundFamily)
        
        print("✅ Schema validation with container creation successful")
    }
    
    func testFallbackContainerWithValidation() {
        // Test that the fallback container creation works with schema validation
        print("🧪 Testing fallback container with schema validation...")
        
        let container = ModelContainerConfiguration.createWithFallback()
        XCTAssertNotNil(container)
        
        // Test that the container is functional
        let context = container.mainContext
        
        let testUser = UserProfile(
            displayName: "Validation Test User",
            appleUserIdHash: "validation_hash"
        )
        
        context.insert(testUser)
        
        do {
            let descriptor = FetchDescriptor<UserProfile>()
            let users = try context.fetch(descriptor)
            let foundUser = users.first { $0.displayName == "Validation Test User" }
            XCTAssertNotNil(foundUser)
            
            print("✅ Fallback container with validation successful")
        } catch {
            XCTFail("Fallback container should be functional: \(error)")
        }
    }
}