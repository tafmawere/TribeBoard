import Foundation
import XCTest

/// Analyzes test coverage for database operations and generates coverage reports
class TestCoverageAnalyzer {
    
    // MARK: - Shared Instance
    
    static let shared = TestCoverageAnalyzer()
    
    // MARK: - Properties
    
    private var coveredOperations: Set<String> = []
    private var allOperations: Set<String> = []
    private var operationCategories: [String: Set<String>] = [:]
    
    // MARK: - Initialization
    
    private init() {
        setupExpectedOperations()
    }
    
    // MARK: - Setup
    
    /// Sets up the expected database operations that should be covered by tests
    private func setupExpectedOperations() {
        // Family operations
        let familyOperations: Set<String> = [
            "Family.create",
            "Family.fetchByCode",
            "Family.fetchById",
            "Family.update",
            "Family.delete",
            "Family.generateUniqueCode",
            "Family.validate",
            "Family.toCKRecord",
            "Family.updateFromCKRecord"
        ]
        
        // UserProfile operations
        let userProfileOperations: Set<String> = [
            "UserProfile.create",
            "UserProfile.fetchByAppleId",
            "UserProfile.fetchById",
            "UserProfile.update",
            "UserProfile.delete",
            "UserProfile.validate",
            "UserProfile.toCKRecord",
            "UserProfile.updateFromCKRecord"
        ]
        
        // Membership operations
        let membershipOperations: Set<String> = [
            "Membership.create",
            "Membership.fetchByFamilyAndUser",
            "Membership.fetchByFamily",
            "Membership.fetchByUser",
            "Membership.updateRole",
            "Membership.remove",
            "Membership.validate",
            "Membership.canChangeRole",
            "Membership.toCKRecord",
            "Membership.updateFromCKRecord"
        ]
        
        // CloudKit operations
        let cloudKitOperations: Set<String> = [
            "CloudKit.sync",
            "CloudKit.upload",
            "CloudKit.download",
            "CloudKit.resolveConflict",
            "CloudKit.handleError",
            "CloudKit.setupSubscriptions",
            "CloudKit.processRemoteNotification"
        ]
        
        // Performance operations
        let performanceOperations: Set<String> = [
            "Performance.bulkCreate",
            "Performance.bulkFetch",
            "Performance.bulkUpdate",
            "Performance.bulkDelete",
            "Performance.memoryUsage",
            "Performance.concurrentOperations"
        ]
        
        // Integration operations
        let integrationOperations: Set<String> = [
            "Integration.familyCreationWorkflow",
            "Integration.familyJoiningWorkflow",
            "Integration.roleManagementWorkflow",
            "Integration.syncWorkflow",
            "Integration.offlineOnlineTransition",
            "Integration.appLaunchInitialization"
        ]
        
        // Schema operations
        let schemaOperations: Set<String> = [
            "Schema.migration",
            "Schema.validation",
            "Schema.relationshipSetup",
            "Schema.constraintEnforcement",
            "Schema.cloudKitSchemaMigration"
        ]
        
        // Store operations by category
        operationCategories["Family"] = familyOperations
        operationCategories["UserProfile"] = userProfileOperations
        operationCategories["Membership"] = membershipOperations
        operationCategories["CloudKit"] = cloudKitOperations
        operationCategories["Performance"] = performanceOperations
        operationCategories["Integration"] = integrationOperations
        operationCategories["Schema"] = schemaOperations
        
        // Combine all operations
        allOperations = familyOperations
            .union(userProfileOperations)
            .union(membershipOperations)
            .union(cloudKitOperations)
            .union(performanceOperations)
            .union(integrationOperations)
            .union(schemaOperations)
    }
    
    // MARK: - Coverage Tracking
    
    /// Marks an operation as covered by tests
    func markOperationCovered(_ operation: String) {
        coveredOperations.insert(operation)
    }
    
    /// Marks multiple operations as covered
    func markOperationsCovered(_ operations: [String]) {
        for operation in operations {
            coveredOperations.insert(operation)
        }
    }
    
    /// Checks if an operation is covered
    func isOperationCovered(_ operation: String) -> Bool {
        return coveredOperations.contains(operation)
    }
    
    // MARK: - Coverage Analysis
    
    /// Calculates overall coverage percentage
    func calculateOverallCoverage() -> Double {
        guard !allOperations.isEmpty else { return 0.0 }
        return Double(coveredOperations.count) / Double(allOperations.count)
    }
    
    /// Calculates coverage for a specific category
    func calculateCategoryCoverage(_ category: String) -> Double {
        guard let categoryOperations = operationCategories[category],
              !categoryOperations.isEmpty else { return 0.0 }
        
        let coveredInCategory = categoryOperations.intersection(coveredOperations)
        return Double(coveredInCategory.count) / Double(categoryOperations.count)
    }
    
    /// Gets uncovered operations
    func getUncoveredOperations() -> Set<String> {
        return allOperations.subtracting(coveredOperations)
    }
    
    /// Gets uncovered operations for a specific category
    func getUncoveredOperations(for category: String) -> Set<String> {
        guard let categoryOperations = operationCategories[category] else { return [] }
        return categoryOperations.subtracting(coveredOperations)
    }
    
    /// Gets coverage summary by category
    func getCoverageSummary() -> [String: CoverageSummary] {
        var summary: [String: CoverageSummary] = [:]
        
        for (category, operations) in operationCategories {
            let coveredInCategory = operations.intersection(coveredOperations)
            let uncoveredInCategory = operations.subtracting(coveredOperations)
            
            summary[category] = CoverageSummary(
                category: category,
                totalOperations: operations.count,
                coveredOperations: coveredInCategory.count,
                uncoveredOperations: uncoveredInCategory.count,
                coveragePercentage: Double(coveredInCategory.count) / Double(operations.count),
                uncoveredOperationsList: Array(uncoveredInCategory).sorted()
            )
        }
        
        return summary
    }
    
    // MARK: - Report Generation
    
    /// Generates a comprehensive coverage report
    func generateCoverageReport() -> CoverageReport {
        let summary = getCoverageSummary()
        let overallCoverage = calculateOverallCoverage()
        let uncoveredOperations = getUncoveredOperations()
        
        return CoverageReport(
            timestamp: Date(),
            overallCoverage: overallCoverage,
            totalOperations: allOperations.count,
            coveredOperations: coveredOperations.count,
            uncoveredOperations: uncoveredOperations.count,
            categorySummaries: summary,
            uncoveredOperationsList: Array(uncoveredOperations).sorted(),
            recommendations: generateRecommendations(summary: summary, uncoveredOperations: uncoveredOperations)
        )
    }
    
    /// Prints coverage report to console
    func printCoverageReport() {
        let report = generateCoverageReport()
        
        print("\n" + "="*80)
        print("📊 DATABASE TEST COVERAGE REPORT")
        print("="*80)
        
        // Overall summary
        print("\n📈 OVERALL COVERAGE")
        print("   Total Operations: \(report.totalOperations)")
        print("   Covered Operations: \(report.coveredOperations)")
        print("   Uncovered Operations: \(report.uncoveredOperations)")
        print("   Coverage Percentage: \(String(format: "%.1f", report.overallCoverage * 100))%")
        
        // Coverage by category
        print("\n📋 COVERAGE BY CATEGORY")
        for (category, summary) in report.categorySummaries.sorted(by: { $0.key < $1.key }) {
            let percentage = String(format: "%.1f", summary.coveragePercentage * 100)
            let status = summary.coveragePercentage >= 0.8 ? "✅" : summary.coveragePercentage >= 0.6 ? "⚠️" : "❌"
            
            print("   \(status) \(category): \(summary.coveredOperations)/\(summary.totalOperations) (\(percentage)%)")
            
            if !summary.uncoveredOperationsList.isEmpty && summary.uncoveredOperationsList.count <= 5 {
                for operation in summary.uncoveredOperationsList {
                    print("     - Missing: \(operation)")
                }
            } else if summary.uncoveredOperationsList.count > 5 {
                print("     - \(summary.uncoveredOperationsList.count) operations missing")
            }
        }
        
        // Recommendations
        if !report.recommendations.isEmpty {
            print("\n💡 RECOMMENDATIONS")
            for (index, recommendation) in report.recommendations.enumerated() {
                print("   \(index + 1). \(recommendation)")
            }
        }
        
        // Critical gaps
        let criticalGaps = report.categorySummaries.filter { $0.value.coveragePercentage < 0.5 }
        if !criticalGaps.isEmpty {
            print("\n🚨 CRITICAL COVERAGE GAPS")
            for (category, summary) in criticalGaps {
                print("   \(category): Only \(String(format: "%.1f", summary.coveragePercentage * 100))% covered")
            }
        }
        
        print("\n" + "="*80)
    }
    
    /// Saves coverage report to JSON file
    func saveCoverageReport() -> URL? {
        let report = generateCoverageReport()
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let jsonData = try encoder.encode(report)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let reportURL = documentsPath.appendingPathComponent("coverage-report-\(Int(Date().timeIntervalSince1970)).json")
            
            try jsonData.write(to: reportURL)
            print("💾 Coverage report saved to: \(reportURL.path)")
            
            return reportURL
        } catch {
            print("❌ Failed to save coverage report: \(error)")
            return nil
        }
    }
    
    // MARK: - Recommendations
    
    /// Generates recommendations based on coverage analysis
    private func generateRecommendations(summary: [String: CoverageSummary], uncoveredOperations: Set<String>) -> [String] {
        var recommendations: [String] = []
        
        // Overall coverage recommendations
        let overallCoverage = calculateOverallCoverage()
        if overallCoverage < 0.8 {
            recommendations.append("Overall coverage is \(String(format: "%.1f", overallCoverage * 100))%. Aim for at least 80% coverage.")
        }
        
        // Category-specific recommendations
        for (category, categorySummary) in summary {
            if categorySummary.coveragePercentage < 0.6 {
                recommendations.append("Add more tests for \(category) operations (currently \(String(format: "%.1f", categorySummary.coveragePercentage * 100))%).")
            }
        }
        
        // Specific operation recommendations
        let criticalOperations = [
            "Family.create", "Family.validate", "UserProfile.create", "UserProfile.validate",
            "Membership.create", "Membership.validate", "CloudKit.sync", "CloudKit.resolveConflict"
        ]
        
        let missingCriticalOperations = criticalOperations.filter { !coveredOperations.contains($0) }
        if !missingCriticalOperations.isEmpty {
            recommendations.append("Add tests for critical operations: \(missingCriticalOperations.joined(separator: ", "))")
        }
        
        // Performance testing recommendations
        let performanceCoverage = calculateCategoryCoverage("Performance")
        if performanceCoverage < 0.7 {
            recommendations.append("Increase performance test coverage (currently \(String(format: "%.1f", performanceCoverage * 100))%).")
        }
        
        // Integration testing recommendations
        let integrationCoverage = calculateCategoryCoverage("Integration")
        if integrationCoverage < 0.8 {
            recommendations.append("Add more integration tests to cover end-to-end workflows.")
        }
        
        return recommendations
    }
    
    // MARK: - Utility Methods
    
    /// Resets coverage tracking
    func reset() {
        coveredOperations.removeAll()
    }
    
    /// Adds a custom operation to track
    func addCustomOperation(_ operation: String, category: String) {
        allOperations.insert(operation)
        
        if operationCategories[category] != nil {
            operationCategories[category]?.insert(operation)
        } else {
            operationCategories[category] = [operation]
        }
    }
}

// MARK: - Data Models

/// Represents coverage summary for a category
struct CoverageSummary: Codable {
    let category: String
    let totalOperations: Int
    let coveredOperations: Int
    let uncoveredOperations: Int
    let coveragePercentage: Double
    let uncoveredOperationsList: [String]
}

/// Represents a complete coverage report
struct CoverageReport: Codable {
    let timestamp: Date
    let overallCoverage: Double
    let totalOperations: Int
    let coveredOperations: Int
    let uncoveredOperations: Int
    let categorySummaries: [String: CoverageSummary]
    let uncoveredOperationsList: [String]
    let recommendations: [String]
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    
    /// Convenience method to mark operations as covered in tests
    func markCovered(_ operations: String...) {
        TestCoverageAnalyzer.shared.markOperationsCovered(operations)
    }
    
    /// Convenience method to mark a single operation as covered
    func markCovered(_ operation: String) {
        TestCoverageAnalyzer.shared.markOperationCovered(operation)
    }
}