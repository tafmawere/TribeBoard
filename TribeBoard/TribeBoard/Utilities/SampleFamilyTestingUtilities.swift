import Foundation

/// Manual testing utilities for sample family data generation and validation
/// Provides console commands and helpers for testing family code generation and join family functionality
class SampleFamilyTestingUtilities {
    
    private let dataService: DataService
    private let generator: SampleFamilyDataGenerator
    
    init(dataService: DataService) {
        self.dataService = dataService
        self.generator = SampleFamilyDataGenerator(dataService: dataService)
    }
    
    // MARK: - Console Commands for Testing
    
    /// Generates sample families and outputs codes for manual testing
    /// Usage: Call this method from Xcode debug console or demo menu
    func generateAndDisplayFamilyCodes() async {
        printSectionHeader("Sample Family Generation")
        
        do {
            let generatedFamilies = try await generator.generateSampleFamilies()
            
            if generatedFamilies.isEmpty {
                print("⚠️  No families were generated. They may already exist.")
                await displayExistingFamilyCodes()
            } else {
                print("✅ Successfully generated \(generatedFamilies.count) sample families!")
                displayFamilyCodesTable(generatedFamilies)
            }
            
            printUsageInstructions()
            
        } catch {
            print("❌ Error generating sample families: \(error.localizedDescription)")
            printErrorRecoveryInstructions(error: error)
        }
    }
    
    /// Displays existing sample family codes without generating new ones
    func displayExistingFamilyCodes() async {
        printSectionHeader("Existing Sample Family Codes")
        
        do {
            let existingFamilies = try await findExistingSampleFamilies()
            
            if existingFamilies.isEmpty {
                print("📝 No sample families found in database.")
                print("💡 Run generateAndDisplayFamilyCodes() to create sample families.")
            } else {
                print("📋 Found \(existingFamilies.count) existing sample families:")
                displayFamilyCodesTable(existingFamilies)
                printUsageInstructions()
            }
            
        } catch {
            print("❌ Error fetching existing families: \(error.localizedDescription)")
        }
    }
    
    /// Validates a specific family code for testing
    /// - Parameter code: The family code to validate
    func validateFamilyCode(_ code: String) async {
        printSectionHeader("Family Code Validation")
        
        print("🔍 Validating family code: '\(code)'")
        
        // Format validation
        let isValidFormat = FamilyCodeGenerator.isValidCodeFormat(code)
        print("📝 Format validation: \(isValidFormat ? "✅ VALID" : "❌ INVALID")")
        
        if !isValidFormat {
            printCodeFormatRequirements()
            return
        }
        
        // Database existence check
        do {
            let codeExists = try await dataService.familyCodeExists(code)
            print("🗄️  Database check: \(codeExists ? "✅ EXISTS" : "❌ NOT FOUND")")
            
            if codeExists {
                if let family = try await dataService.fetchFamily(byCode: code) {
                    await displayFamilyDetails(family)
                }
            } else {
                print("💡 This code is not in the database. It may be a valid format but not an active family code.")
            }
            
        } catch {
            print("❌ Error checking database: \(error.localizedDescription)")
        }
    }
    
    /// Tests the join family workflow with a specific code
    /// - Parameter code: The family code to test joining
    func testJoinFamilyWorkflow(_ code: String) async {
        printSectionHeader("Join Family Workflow Test")
        
        print("🧪 Testing join family workflow with code: '\(code)'")
        
        do {
            // Step 1: Validate code format
            guard FamilyCodeGenerator.isValidCodeFormat(code) else {
                print("❌ Step 1 FAILED: Invalid code format")
                printCodeFormatRequirements()
                return
            }
            print("✅ Step 1 PASSED: Code format is valid")
            
            // Step 2: Check if family exists
            guard let family = try await dataService.fetchFamily(byCode: code) else {
                print("❌ Step 2 FAILED: Family not found with code '\(code)'")
                print("💡 Make sure the family code exists in the database")
                return
            }
            print("✅ Step 2 PASSED: Family found - '\(family.name)'")
            
            // Step 3: Check family has members
            let memberships = try await dataService.fetchMemberships(forFamily: family)
            guard !memberships.isEmpty else {
                print("❌ Step 3 FAILED: Family has no members")
                return
            }
            print("✅ Step 3 PASSED: Family has \(memberships.count) members")
            
            // Step 4: Verify admin exists
            let adminMemberships = memberships.filter { $0.role == .parentAdmin }
            guard adminMemberships.count == 1 else {
                print("❌ Step 4 FAILED: Family should have exactly 1 admin, found \(adminMemberships.count)")
                return
            }
            print("✅ Step 4 PASSED: Family has proper admin structure")
            
            // Step 5: Display family information for manual verification
            await displayFamilyDetails(family)
            
            print("\n🎉 Join family workflow test COMPLETED SUCCESSFULLY!")
            print("💡 You can now use this code '\(code)' to test the actual join family UI")
            
        } catch {
            print("❌ Join family workflow test FAILED: \(error.localizedDescription)")
        }
    }
    
    /// Cleans up all sample family data for testing reset scenarios
    func cleanupSampleFamilies() async {
        printSectionHeader("Sample Family Cleanup")
        
        print("🧹 Cleaning up sample family data...")
        print("⚠️  This will remove all sample families and their members from the database.")
        
        do {
            let existingFamilies = try await findExistingSampleFamilies()
            
            if existingFamilies.isEmpty {
                print("✅ No sample families found to clean up.")
                return
            }
            
            print("🗑️  Found \(existingFamilies.count) sample families to remove:")
            for family in existingFamilies {
                print("   - \(family.family.name) (Code: \(family.code))")
            }
            
            // Note: Actual cleanup implementation would depend on DataService having delete methods
            // For now, we'll just report what would be cleaned up
            print("\n💡 Cleanup functionality requires DataService delete methods.")
            print("   Manual cleanup: Delete families with names containing 'Johnson', 'Garcia', 'Chen', 'Williams', 'Anderson'")
            
        } catch {
            print("❌ Error during cleanup: \(error.localizedDescription)")
        }
    }
    
    /// Generates a test report for QA validation
    func generateTestReport() async {
        printSectionHeader("Sample Family Test Report")
        
        let timestamp = DateFormatter.testReportFormatter.string(from: Date())
        print("📊 Test Report Generated: \(timestamp)")
        print("=" * 60)
        
        // Test 1: Family Generation
        print("\n🧪 TEST 1: Family Generation")
        do {
            let families = try await findExistingSampleFamilies()
            let expectedCount = 5
            
            print("Expected families: \(expectedCount)")
            print("Actual families: \(families.count)")
            print("Status: \(families.count == expectedCount ? "✅ PASS" : "❌ FAIL")")
            
            if families.count != expectedCount {
                print("💡 Run generateAndDisplayFamilyCodes() to create missing families")
            }
        } catch {
            print("Status: ❌ ERROR - \(error.localizedDescription)")
        }
        
        // Test 2: Code Format Validation
        print("\n🧪 TEST 2: Code Format Validation")
        do {
            let families = try await findExistingSampleFamilies()
            var validCodes = 0
            
            for family in families {
                if FamilyCodeGenerator.isValidCodeFormat(family.code) {
                    validCodes += 1
                } else {
                    print("❌ Invalid code format: '\(family.code)' for family '\(family.family.name)'")
                }
            }
            
            print("Valid codes: \(validCodes)/\(families.count)")
            print("Status: \(validCodes == families.count ? "✅ PASS" : "❌ FAIL")")
            
        } catch {
            print("Status: ❌ ERROR - \(error.localizedDescription)")
        }
        
        // Test 3: Family Structure Validation
        print("\n🧪 TEST 3: Family Structure Validation")
        await validateFamilyStructures()
        
        // Test 4: Join Family Workflow
        print("\n🧪 TEST 4: Join Family Workflow Readiness")
        do {
            let families = try await findExistingSampleFamilies()
            var readyFamilies = 0
            
            for family in families {
                let memberships = try await dataService.fetchMemberships(forFamily: family.family)
                let adminCount = memberships.filter { $0.role == .parentAdmin }.count
                
                if adminCount == 1 && !memberships.isEmpty {
                    readyFamilies += 1
                } else {
                    print("❌ Family '\(family.family.name)' not ready: \(adminCount) admins, \(memberships.count) total members")
                }
            }
            
            print("Ready families: \(readyFamilies)/\(families.count)")
            print("Status: \(readyFamilies == families.count ? "✅ PASS" : "❌ FAIL")")
            
        } catch {
            print("Status: ❌ ERROR - \(error.localizedDescription)")
        }
        
        print("\n" + "=" * 60)
        print("📋 Test report complete. Use family codes above for manual UI testing.")
    }
    
    // MARK: - Private Helper Methods
    
    private func findExistingSampleFamilies() async throws -> [GeneratedFamilyInfo] {
        // This would need to be implemented based on how we can query existing families
        // For now, we'll return an empty array and note that this needs DataService query methods
        
        let allFamilies = try await dataService.fetchAllFamilies()
        let sampleFamilyNames = ["Johnson", "Garcia", "Chen", "Williams", "Anderson"]
        
        let sampleFamilies = allFamilies.filter { family in
            sampleFamilyNames.contains { family.name.contains($0) }
        }
        
        return sampleFamilies.map { family in
            GeneratedFamilyInfo(
                family: family,
                code: family.code,
                memberCount: 0 // Would need to query memberships to get actual count
            )
        }
    }
    
    private func displayFamilyCodesTable(_ families: [GeneratedFamilyInfo]) {
        print("\n📋 Family Codes for Testing:")
        print("+" + "-" * 58 + "+")
        print("| Family Name                    | Code   | Members |")
        print("+" + "-" * 58 + "+")
        
        for family in families {
            let name = family.family.name.padding(toLength: 30, withPad: " ", startingAt: 0)
            let code = family.code.padding(toLength: 6, withPad: " ", startingAt: 0)
            let members = String(family.memberCount).padding(toLength: 7, withPad: " ", startingAt: 0)
            print("| \(name) | \(code) | \(members) |")
        }
        
        print("+" + "-" * 58 + "+")
    }
    
    private func displayFamilyDetails(_ family: Family) async {
        print("\n👨‍👩‍👧‍👦 Family Details:")
        print("   Name: \(family.name)")
        print("   Code: \(family.code)")
        print("   Created: \(DateFormatter.displayFormatter.string(from: family.createdAt))")
        
        do {
            let memberships = try await dataService.fetchMemberships(forFamily: family)
            print("   Members: \(memberships.count)")
            
            for membership in memberships {
                if let userId = membership.userId,
                   let user = try await dataService.fetchUserProfile(byId: userId) {
                    let roleIcon = membership.role == .parentAdmin ? "👑" : 
                                  membership.role == .adult ? "👤" : "👶"
                    print("     \(roleIcon) \(user.displayName) (\(membership.role.displayName))")
                }
            }
        } catch {
            print("   ❌ Error fetching members: \(error.localizedDescription)")
        }
    }
    
    private func validateFamilyStructures() async {
        do {
            let families = try await findExistingSampleFamilies()
            var validFamilies = 0
            
            for family in families {
                let memberships = try await dataService.fetchMemberships(forFamily: family.family)
                let adminCount = memberships.filter { $0.role == .parentAdmin }.count
                let totalMembers = memberships.count
                
                let isValid = adminCount == 1 && totalMembers >= 1 && totalMembers <= 5
                
                if isValid {
                    validFamilies += 1
                } else {
                    print("❌ Invalid structure - \(family.family.name): \(adminCount) admins, \(totalMembers) members")
                }
            }
            
            print("Valid structures: \(validFamilies)/\(families.count)")
            print("Status: \(validFamilies == families.count ? "✅ PASS" : "❌ FAIL")")
            
        } catch {
            print("Status: ❌ ERROR - \(error.localizedDescription)")
        }
    }
    
    private func printSectionHeader(_ title: String) {
        let border = "=" * max(title.count + 4, 50)
        print("\n\(border)")
        print("  \(title)")
        print(border)
    }
    
    private func printUsageInstructions() {
        print("\n💡 Usage Instructions:")
        print("1. Copy any family code from the table above")
        print("2. Open the TribeBoard app")
        print("3. Navigate to 'Join Existing Family'")
        print("4. Enter the copied code")
        print("5. Test the join family workflow")
        print("\n🔧 Additional Testing Commands:")
        print("• validateFamilyCode(\"CODE123\") - Validate a specific code")
        print("• testJoinFamilyWorkflow(\"CODE123\") - Test complete join workflow")
        print("• generateTestReport() - Generate comprehensive test report")
    }
    
    private func printCodeFormatRequirements() {
        print("\n📝 Family Code Format Requirements:")
        print("• Exactly 6 characters long")
        print("• Only uppercase letters (A-Z) and numbers (0-9)")
        print("• No spaces, hyphens, or special characters")
        print("• Examples: ABC123, XYZ789, FAM001")
    }
    
    private func printErrorRecoveryInstructions(error: Error) {
        print("\n🔧 Error Recovery Instructions:")
        
        if let sampleError = error as? SampleDataError {
            switch sampleError {
            case .familyAlreadyExists:
                print("• Families already exist - use displayExistingFamilyCodes()")
            case .codeGenerationFailed:
                print("• Try running the generation again")
                print("• Check if database has too many existing families")
            case .dataServiceUnavailable:
                print("• Ensure the app is properly initialized")
                print("• Check database connection")
            case .networkError:
                print("• Check internet connection")
                print("• Try again when network is stable")
            default:
                print("• Check console logs for detailed error information")
                print("• Try restarting the app if problem persists")
            }
        } else {
            print("• Check console logs for detailed error information")
            print("• Ensure database is accessible and app is properly initialized")
        }
    }
}

// MARK: - Extensions for Testing Utilities

extension DateFormatter {
    static let testReportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// MARK: - Console Testing Interface

/// Global testing interface for easy console access
/// Usage in Xcode debug console:
/// ```
/// let testUtils = SampleFamilyTestingUtilities(dataService: yourDataService)
/// await testUtils.generateAndDisplayFamilyCodes()
/// ```
class SampleFamilyConsoleInterface {
    
    /// Quick access method for generating and displaying family codes
    /// Call this from Xcode debug console: SampleFamilyConsoleInterface.quickTest()
    static func quickTest(with dataService: DataService) async {
        let testUtils = SampleFamilyTestingUtilities(dataService: dataService)
        await testUtils.generateAndDisplayFamilyCodes()
    }
    
    /// Quick validation of a family code
    /// Call this from Xcode debug console: SampleFamilyConsoleInterface.quickValidate("ABC123", with: dataService)
    static func quickValidate(_ code: String, with dataService: DataService) async {
        let testUtils = SampleFamilyTestingUtilities(dataService: dataService)
        await testUtils.validateFamilyCode(code)
    }
    
    /// Quick test report generation
    /// Call this from Xcode debug console: SampleFamilyConsoleInterface.quickReport(with: dataService)
    static func quickReport(with dataService: DataService) async {
        let testUtils = SampleFamilyTestingUtilities(dataService: dataService)
        await testUtils.generateTestReport()
    }
}