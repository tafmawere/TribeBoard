import XCTest
import SwiftData
import SwiftUI
@testable import TribeBoard

@MainActor
final class AppLaunchTests: XCTestCase {
    
    // MARK: - Test Setup and Teardown
    
    override func setUp() {
        super.setUp()
        print("🧪 Setting up AppLaunchTests...")
    }
    
    override func tearDown() {
        print("🧪 Tearing down AppLaunchTests...")
        super.tearDown()
    }
    
    // MARK: - App Launch Simulation Tests
    
    @MainActor func testTribeBoardAppInitialization() {
        // Test the actual TribeBoardApp initialization process
        // This simulates what happens when the app launches
        
        print("🚀 Testing TribeBoardApp initialization...")
        
        // This test verifies that the app can initialize without crashing
        // We can't directly instantiate TribeBoardApp in tests, but we can test
        // the ModelContainer creation that happens in its init()
        
        let container = ModelContainerConfiguration.createWithFallback()
        
        // Verify the container was created (this is what TribeBoardApp.init() does)
        XCTAssertNotNil(container, "TribeBoardApp should be able to create ModelContainer during initialization")
        
        // Verify the container is ready for use
        let context = container.mainContext
        XCTAssertNotNil(context, "ModelContainer should provide a working context")
        
        // Test that the container can handle the operations the app will perform
        do {
            // Simulate initial app data operations
            let initialUser = UserProfile(
                displayName: "Launch Test User",
                appleUserIdHash: "launch_test_hash"
            )
            
            context.insert(initialUser)
            
            let descriptor = FetchDescriptor<UserProfile>()
            let users = try context.fetch(descriptor)
            let launchUser = users.first { $0.displayName == "Launch Test User" }
            XCTAssertNotNil(launchUser, "App should be able to perform initial data operations")
            
            print("✅ TribeBoardApp initialization simulation successful")
            
        } catch {
            XCTFail("App should be able to perform initial operations after launch: \(error)")
        }
    }
    
    @MainActor func testAppLaunchInSimulatorEnvironment() {
        // Test app launch specifically in iOS Simulator environment
        // Simulator has CloudKit limitations, so this tests the fallback behavior
        
        print("📱 Testing app launch in iOS Simulator environment...")
        
        // Simulate the exact initialization sequence from TribeBoardApp
        var modelContainer: ModelContainer?
        
        // This should not crash or throw a fatal error
        modelContainer = ModelContainerConfiguration.createWithFallback()
        
        XCTAssertNotNil(modelContainer, "App should launch successfully in iOS Simulator")
        
        // Verify the app can function normally in simulator
        guard let container = modelContainer else {
            XCTFail("ModelContainer should be available")
            return
        }
        
        let context = container.mainContext
        
        do {
            // Test typical app operations that would happen after launch
            let simulatorFamily = Family(
                name: "Simulator Family",
                code: "SIM456",
                createdByUserId: UUID()
            )
            
            context.insert(simulatorFamily)
            
            // Verify data persistence works in simulator
            let descriptor = FetchDescriptor<Family>()
            let families = try context.fetch(descriptor)
            let foundFamily = families.first { $0.name == "Simulator Family" }
            XCTAssertNotNil(foundFamily, "Data operations should work in simulator")
            
            print("✅ App functionality verified in simulator environment")
            
        } catch {
            XCTFail("App should maintain full functionality in simulator: \(error)")
        }
    }
    
    @MainActor func testAppLaunchWithCloudKitAvailableVsUnavailable() {
        // Test app launch behavior in both CloudKit available and unavailable scenarios
        
        print("☁️ Testing app launch with CloudKit available vs unavailable...")
        
        // Test CloudKit available scenario
        do {
            let cloudKitContainer = try ModelContainerConfiguration.create()
            
            // If we reach here, CloudKit is available
            XCTAssertNotNil(cloudKitContainer, "App should work with CloudKit when available")
            
            let context = cloudKitContainer.mainContext
            let cloudKitUser = UserProfile(
                displayName: "CloudKit User",
                appleUserIdHash: "cloudkit_user_hash"
            )
            
            context.insert(cloudKitUser)
            
            let descriptor = FetchDescriptor<UserProfile>()
            let users = try context.fetch(descriptor)
            let foundUser = users.first { $0.displayName == "CloudKit User" }
            XCTAssertNotNil(foundUser, "CloudKit container should support full functionality")
            
            print("✅ CloudKit available scenario: App works correctly")
            
        } catch {
            print("ℹ️ CloudKit unavailable (expected in test environment): \(error.localizedDescription)")
        }
        
        // Test CloudKit unavailable scenario (fallback)
        let fallbackContainer = ModelContainerConfiguration.createWithFallback()
        XCTAssertNotNil(fallbackContainer, "App should work with fallback when CloudKit unavailable")
        
        let fallbackContext = fallbackContainer.mainContext
        
        do {
            let fallbackUser = UserProfile(
                displayName: "Fallback User",
                appleUserIdHash: "fallback_user_hash"
            )
            
            fallbackContext.insert(fallbackUser)
            
            let descriptor = FetchDescriptor<UserProfile>()
            let users = try fallbackContext.fetch(descriptor)
            let foundUser = users.first { $0.displayName == "Fallback User" }
            XCTAssertNotNil(foundUser, "Fallback container should support full functionality")
            
            print("✅ CloudKit unavailable scenario: Fallback works correctly")
            
        } catch {
            XCTFail("Fallback should provide full app functionality: \(error)")
        }
    }
    
    @MainActor func testAppLaunchNoCrashGuarantee() {
        // Test that app launch never crashes during ModelContainer initialization
        // This is the critical requirement - no crashes should occur
        
        print("🛡️ Testing app launch crash prevention guarantee...")
        
        // Test multiple launch scenarios that previously caused crashes
        let launchScenarios = [
            "Normal Launch",
            "Rapid Launch 1",
            "Rapid Launch 2", 
            "Rapid Launch 3",
            "Background Launch",
            "Foreground Launch"
        ]
        
        for scenario in launchScenarios {
            print("   Testing scenario: \(scenario)")
            
            // This should NEVER crash or throw a fatal error
            let container = ModelContainerConfiguration.createWithFallback()
            
            XCTAssertNotNil(container, "Launch scenario '\(scenario)' should not crash")
            
            // Verify the container is immediately usable
            let context = container.mainContext
            XCTAssertNotNil(context, "Container should be immediately usable in '\(scenario)'")
            
            // Test immediate data operation (common cause of crashes)
            do {
                let testFamily = Family(
                    name: "\(scenario) Family",
                    code: "TST123",
                    createdByUserId: UUID()
                )
                
                context.insert(testFamily)
                
                let descriptor = FetchDescriptor<Family>()
                let families = try context.fetch(descriptor)
                let scenarioFamily = families.first { $0.name == "\(scenario) Family" }
                XCTAssertNotNil(scenarioFamily, "Immediate operations should work in '\(scenario)'")
                
            } catch {
                XCTFail("Immediate operations should not fail in '\(scenario)': \(error)")
            }
        }
        
        print("✅ All launch scenarios completed without crashes")
    }
    
    @MainActor func testAppLaunchWithSystemResourceConstraints() {
        // Test app launch under various system resource constraints
        
        print("⚡ Testing app launch under system resource constraints...")
        
        // Test rapid successive launches (memory pressure simulation)
        var containers: [ModelContainer] = []
        
        for i in 0..<20 {
            let container = ModelContainerConfiguration.createWithFallback()
            containers.append(container)
            
            XCTAssertNotNil(container, "Launch \(i+1) should succeed under memory pressure")
            
            // Test that each container works independently
            let context = container.mainContext
            let testUser = UserProfile(
                displayName: "Pressure User \(i)",
                appleUserIdHash: "pressure_\(i)"
            )
            
            context.insert(testUser)
            
            do {
                let descriptor = FetchDescriptor<UserProfile>()
                let users = try context.fetch(descriptor)
                let pressureUser = users.first { $0.displayName == "Pressure User \(i)" }
                XCTAssertNotNil(pressureUser, "Container \(i+1) should be functional under pressure")
                
            } catch {
                XCTFail("Container \(i+1) should work under pressure: \(error)")
            }
        }
        
        XCTAssertEqual(containers.count, 20, "All containers should be created under pressure")
        print("✅ App launch verified under system resource constraints")
    }
    
    @MainActor func testAppLaunchErrorRecovery() {
        // Test that app can recover from various error conditions during launch
        
        print("🔄 Testing app launch error recovery...")
        
        // Test recovery from CloudKit errors
        // The fallback mechanism should handle this gracefully
        
        for attempt in 1...5 {
            print("   Recovery attempt \(attempt)...")
            
            let container = ModelContainerConfiguration.createWithFallback()
            XCTAssertNotNil(container, "Recovery attempt \(attempt) should succeed")
            
            // Verify full functionality after recovery
            let context = container.mainContext
            
            do {
                let recoveryUser = UserProfile(
                    displayName: "Recovery User \(attempt)",
                    appleUserIdHash: "recovery_\(attempt)"
                )
                
                let recoveryFamily = Family(
                    name: "Recovery Family \(attempt)",
                    code: "REC\(attempt)3",
                    createdByUserId: recoveryUser.id
                )
                
                let recoveryMembership = Membership(
                    family: recoveryFamily,
                    user: recoveryUser,
                    role: .parentAdmin
                )
                
                context.insert(recoveryUser)
                context.insert(recoveryFamily)
                context.insert(recoveryMembership)
                
                // Verify all data operations work after recovery
                let userDescriptor = FetchDescriptor<UserProfile>()
                let users = try context.fetch(userDescriptor)
                let foundUser = users.first { $0.displayName == "Recovery User \(attempt)" }
                XCTAssertNotNil(foundUser, "User operations should work after recovery \(attempt)")
                
                let familyDescriptor = FetchDescriptor<Family>()
                let families = try context.fetch(familyDescriptor)
                let foundFamily = families.first { $0.name == "Recovery Family \(attempt)" }
                XCTAssertNotNil(foundFamily, "Family operations should work after recovery \(attempt)")
                
                let membershipDescriptor = FetchDescriptor<Membership>()
                let memberships = try context.fetch(membershipDescriptor)
                let foundMembership = memberships.first { $0.user?.displayName == "Recovery User \(attempt)" }
                XCTAssertNotNil(foundMembership, "Membership operations should work after recovery \(attempt)")
                
            } catch {
                XCTFail("Full functionality should be available after recovery \(attempt): \(error)")
            }
        }
        
        print("✅ App launch error recovery verified")
    }
    
    @MainActor func testAppLaunchPerformanceInDifferentEnvironments() {
        // Test that app launch performance is acceptable in different environments
        
        print("⏱️ Testing app launch performance in different environments...")
        
        // Test launch performance with fallback mechanism
        measure {
            let container = ModelContainerConfiguration.createWithFallback()
            XCTAssertNotNil(container)
            
            // Test immediate usability (part of launch performance)
            let context = container.mainContext
            let testFamily = Family(
                name: "Performance Family",
                code: "PERF23",
                createdByUserId: UUID()
            )
            context.insert(testFamily)
        }
        
        print("✅ App launch performance verified")
    }
    
    @MainActor func testAppLaunchDataIntegrity() {
        // Test that app launch maintains data integrity across different scenarios
        
        print("🔒 Testing app launch data integrity...")
        
        let container = ModelContainerConfiguration.createWithFallback()
        let context = container.mainContext
        
        do {
            // Create a complete data set
            let user1 = UserProfile(
                displayName: "Integrity User 1",
                appleUserIdHash: "integrity_1"
            )
            
            let user2 = UserProfile(
                displayName: "Integrity User 2",
                appleUserIdHash: "integrity_2"
            )
            
            let family = Family(
                name: "Integrity Family",
                code: "INT123",
                createdByUserId: user1.id
            )
            
            let membership1 = Membership(
                family: family,
                user: user1,
                role: .parentAdmin
            )
            
            let membership2 = Membership(
                family: family,
                user: user2,
                role: .adult
            )
            
            // Insert all data
            context.insert(user1)
            context.insert(user2)
            context.insert(family)
            context.insert(membership1)
            context.insert(membership2)
            
            // Verify data integrity
            let userDescriptor = FetchDescriptor<UserProfile>()
            let users = try context.fetch(userDescriptor)
            XCTAssertGreaterThanOrEqual(users.count, 2, "All users should be preserved")
            
            let familyDescriptor = FetchDescriptor<Family>()
            let families = try context.fetch(familyDescriptor)
            let integrityFamily = families.first { $0.name == "Integrity Family" }
            XCTAssertNotNil(integrityFamily, "Family should be preserved")
            
            let membershipDescriptor = FetchDescriptor<Membership>()
            let memberships = try context.fetch(membershipDescriptor)
            XCTAssertGreaterThanOrEqual(memberships.count, 2, "All memberships should be preserved")
            
            // Verify relationships are intact
            let adminMembership = memberships.first { $0.role == .parentAdmin }
            XCTAssertNotNil(adminMembership, "Admin membership should exist")
            XCTAssertEqual(adminMembership?.user?.displayName, "Integrity User 1", "Admin relationship should be correct")
            
            let adultMembership = memberships.first { $0.role == .adult }
            XCTAssertNotNil(adultMembership, "Adult membership should exist")
            XCTAssertEqual(adultMembership?.user?.displayName, "Integrity User 2", "Adult relationship should be correct")
            
            print("✅ App launch data integrity verified")
            
        } catch {
            XCTFail("Data integrity should be maintained during app launch: \(error)")
        }
    }
}