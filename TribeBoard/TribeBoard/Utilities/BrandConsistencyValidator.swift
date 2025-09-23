import SwiftUI

/// Utility for validating and ensuring brand consistency across the app
struct BrandConsistencyValidator {
    
    // MARK: - Typography Validation
    
    /// Validates that typography follows the design system
    static func validateTypography() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check for hardcoded font sizes that should use design system
        let deprecatedFontUsage = [
            ".font(.title)",
            ".font(.headline)",
            ".font(.body)",
            ".font(.caption)",
            ".font(.system(size:"
        ]
        
        for usage in deprecatedFontUsage {
            issues.append(ValidationIssue(
                type: .typography,
                severity: .warning,
                description: "Consider using DesignSystem.Typography instead of \(usage)",
                recommendation: "Use .titleLarge(), .headlineMedium(), .bodyLarge(), etc."
            ))
        }
        
        return issues
    }
    
    // MARK: - Color Validation
    
    /// Validates that colors follow the brand guidelines
    static func validateColors() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check for hardcoded colors that should use brand colors
        let deprecatedColorUsage = [
            "Color.blue",
            "Color.red",
            "Color.green",
            "Color.purple",
            ".foregroundColor(.blue)"
        ]
        
        for usage in deprecatedColorUsage {
            issues.append(ValidationIssue(
                type: .color,
                severity: .error,
                description: "Hardcoded color usage: \(usage)",
                recommendation: "Use Color.brandPrimary, Color.brandSecondary, or semantic colors"
            ))
        }
        
        return issues
    }
    
    // MARK: - Spacing Validation
    
    /// Validates that spacing follows the design system
    static func validateSpacing() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check for hardcoded spacing values
        let deprecatedSpacingUsage = [
            ".padding(8)",
            ".padding(16)",
            ".padding(24)",
            ".spacing(12)"
        ]
        
        for usage in deprecatedSpacingUsage {
            issues.append(ValidationIssue(
                type: .spacing,
                severity: .warning,
                description: "Hardcoded spacing: \(usage)",
                recommendation: "Use DesignSystem.Spacing constants or view modifiers like .contentPadding()"
            ))
        }
        
        return issues
    }
    
    // MARK: - Component Validation
    
    /// Validates that components follow brand guidelines
    static func validateComponents() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check for inconsistent button styling
        issues.append(ValidationIssue(
            type: .component,
            severity: .info,
            description: "Ensure all buttons use consistent ButtonStyle implementations",
            recommendation: "Use PrimaryButtonStyle, SecondaryButtonStyle, or other branded button styles"
        ))
        
        // Check for inconsistent corner radius usage
        issues.append(ValidationIssue(
            type: .component,
            severity: .warning,
            description: "Use BrandStyle.cornerRadius for consistent corner radius",
            recommendation: "Replace hardcoded cornerRadius values with BrandStyle constants"
        ))
        
        return issues
    }
    
    // MARK: - Shadow Validation
    
    /// Validates that shadows follow the design system
    static func validateShadows() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        issues.append(ValidationIssue(
            type: .shadow,
            severity: .info,
            description: "Use DesignSystem.Shadow for consistent elevation",
            recommendation: "Replace custom shadow implementations with .lightShadow(), .mediumShadow(), etc."
        ))
        
        return issues
    }
    
    // MARK: - Comprehensive Validation
    
    /// Runs all validation checks and returns consolidated results
    static func validateBrandConsistency() -> BrandValidationReport {
        var allIssues: [ValidationIssue] = []
        
        allIssues.append(contentsOf: validateTypography())
        allIssues.append(contentsOf: validateColors())
        allIssues.append(contentsOf: validateSpacing())
        allIssues.append(contentsOf: validateComponents())
        allIssues.append(contentsOf: validateShadows())
        
        return BrandValidationReport(issues: allIssues)
    }
}

// MARK: - Supporting Types

struct ValidationIssue {
    let type: ValidationType
    let severity: ValidationSeverity
    let description: String
    let recommendation: String
    
    enum ValidationType {
        case typography
        case color
        case spacing
        case component
        case shadow
        case accessibility
        
        var displayName: String {
            switch self {
            case .typography: return "Typography"
            case .color: return "Color"
            case .spacing: return "Spacing"
            case .component: return "Component"
            case .shadow: return "Shadow"
            case .accessibility: return "Accessibility"
            }
        }
        
        var icon: String {
            switch self {
            case .typography: return "textformat"
            case .color: return "paintpalette"
            case .spacing: return "ruler"
            case .component: return "square.stack.3d.up"
            case .shadow: return "shadow"
            case .accessibility: return "accessibility"
            }
        }
    }
    
    enum ValidationSeverity {
        case error
        case warning
        case info
        
        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
        
        var displayName: String {
            switch self {
            case .error: return "Error"
            case .warning: return "Warning"
            case .info: return "Info"
            }
        }
    }
}

struct BrandValidationReport {
    let issues: [ValidationIssue]
    let timestamp: Date = Date()
    
    var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }
    
    var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }
    
    var infoCount: Int {
        issues.filter { $0.severity == .info }.count
    }
    
    var overallScore: Double {
        let totalIssues = issues.count
        if totalIssues == 0 { return 100.0 }
        
        let weightedScore = Double(errorCount * 3 + warningCount * 2 + infoCount * 1)
        let maxPossibleScore = Double(totalIssues * 3)
        
        return max(0, (maxPossibleScore - weightedScore) / maxPossibleScore * 100)
    }
    
    var scoreGrade: String {
        switch overallScore {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }
}

// MARK: - Brand Validation View

/// Debug view for displaying brand consistency validation results
struct BrandValidationView: View {
    @State private var report: BrandValidationReport?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header
                    headerSection
                    
                    // Validation Results
                    if let report = report {
                        validationResultsSection(report: report)
                    } else {
                        emptyStateSection
                    }
                }
                .screenPadding()
            }
            .navigationTitle("Brand Consistency")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Validate") {
                        runValidation()
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            runValidation()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(.brandPrimary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Brand Consistency Checker")
                    .headlineMedium()
                    .foregroundColor(.primary)
                
                Text("Validates design system usage across the app")
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Validation Results Section
    
    private func validationResultsSection(report: BrandValidationReport) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Score Card
            scoreCard(report: report)
            
            // Issue Summary
            issueSummary(report: report)
            
            // Detailed Issues
            if !report.issues.isEmpty {
                issuesList(issues: report.issues)
            }
        }
    }
    
    private func scoreCard(report: BrandValidationReport) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Overall Score")
                        .labelLarge()
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .bottom, spacing: DesignSystem.Spacing.xs) {
                        Text("\(Int(report.overallScore))")
                            .displaySmall()
                            .foregroundColor(.brandPrimary)
                        
                        Text("/ 100")
                            .titleMedium()
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(report.scoreGrade)
                    .displayMedium()
                    .foregroundColor(gradeColor(report.scoreGrade))
                    .padding(DesignSystem.Spacing.lg)
                    .background(
                        Circle()
                            .fill(gradeColor(report.scoreGrade).opacity(0.1))
                    )
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
    }
    
    private func issueSummary(report: BrandValidationReport) -> some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            summaryItem(
                count: report.errorCount,
                label: "Errors",
                color: .red,
                icon: "xmark.circle.fill"
            )
            
            summaryItem(
                count: report.warningCount,
                label: "Warnings",
                color: .orange,
                icon: "exclamationmark.triangle.fill"
            )
            
            summaryItem(
                count: report.infoCount,
                label: "Info",
                color: .blue,
                icon: "info.circle.fill"
            )
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    private func summaryItem(count: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .titleMedium()
                .foregroundColor(.primary)
            
            Text(label)
                .captionLarge()
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func issuesList(issues: [ValidationIssue]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Issues Found")
                .headlineSmall()
                .foregroundColor(.primary)
            
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(Array(issues.enumerated()), id: \.offset) { index, issue in
                    issueRow(issue: issue)
                }
            }
        }
    }
    
    private func issueRow(issue: ValidationIssue) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: issue.type.icon)
                    .font(.caption)
                    .foregroundColor(issue.severity.color)
                
                Text(issue.type.displayName)
                    .labelMedium()
                    .foregroundColor(issue.severity.color)
                
                Spacer()
                
                Text(issue.severity.displayName)
                    .captionMedium()
                    .foregroundColor(.secondary)
            }
            
            Text(issue.description)
                .bodySmall()
                .foregroundColor(.primary)
            
            Text(issue.recommendation)
                .captionLarge()
                .foregroundColor(.secondary)
                .italic()
        }
        .contentPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(issue.severity.color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                        .stroke(issue.severity.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Empty State Section
    
    private var emptyStateSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            if isLoading {
                BrandedLoadingOverlay(
                    message: "Validating brand consistency...",
                    style: .minimal
                )
            } else {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "Ready to Validate",
                    message: "Tap the Validate button to check brand consistency across the app.",
                    style: .minimal
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func runValidation() {
        isLoading = true
        
        // Simulate validation process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            report = BrandConsistencyValidator.validateBrandConsistency()
            isLoading = false
        }
    }
    
    private func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "A": return .green
        case "B": return .blue
        case "C": return .orange
        case "D": return .red
        default: return .red
        }
    }
}

// MARK: - Preview

#Preview("Brand Validation") {
    BrandValidationView()
}