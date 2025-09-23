import SwiftUI
import UIKit

/// Accessibility audit utilities for TribeBoard prototype
struct AccessibilityAudit {
    
    /// Check if colors meet WCAG contrast requirements
    static func checkColorContrast(_ foreground: Color, background: Color) -> ContrastResult {
        let foregroundLuminance = foreground.luminance
        let backgroundLuminance = background.luminance
        
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        
        let contrastRatio = (lighter + 0.05) / (darker + 0.05)
        
        return ContrastResult(
            ratio: contrastRatio,
            passesAA: contrastRatio >= 4.5,
            passesAAA: contrastRatio >= 7.0
        )
    }
    
    /// Validate touch target sizes
    static func validateTouchTarget(size: CGSize) -> TouchTargetResult {
        let minSize: CGFloat = 44
        
        return TouchTargetResult(
            width: size.width,
            height: size.height,
            meetsMinimum: size.width >= minSize && size.height >= minSize,
            recommendedSize: CGSize(width: max(size.width, minSize), height: max(size.height, minSize))
        )
    }
    
    /// Check dynamic type scaling
    static func checkDynamicTypeSupport(baseSize: CGFloat, for dynamicTypeSize: DynamicTypeSize) -> DynamicTypeResult {
        let scaledSize = baseSize * dynamicTypeSize.scaleFactor
        let maxRecommendedSize = baseSize * 2.0 // 200% scaling limit
        
        return DynamicTypeResult(
            baseSize: baseSize,
            scaledSize: scaledSize,
            isWithinRecommendedRange: scaledSize <= maxRecommendedSize,
            recommendedMaxSize: maxRecommendedSize
        )
    }
    
    /// Generate accessibility report for common issues
    static func generateReport() -> AccessibilityReport {
        var issues: [AccessibilityIssue] = []
        
        // Check brand colors
        let primaryContrast = checkColorContrast(.brandPrimary, background: .white)
        if !primaryContrast.passesAA {
            issues.append(AccessibilityIssue(
                type: .colorContrast,
                severity: .high,
                description: "Brand primary color doesn't meet WCAG AA contrast requirements",
                suggestion: "Use a darker shade or add a background color"
            ))
        }
        
        let secondaryContrast = checkColorContrast(.brandSecondary, background: .white)
        if !secondaryContrast.passesAA {
            issues.append(AccessibilityIssue(
                type: .colorContrast,
                severity: .high,
                description: "Brand secondary color doesn't meet WCAG AA contrast requirements",
                suggestion: "Use a darker shade or add a background color"
            ))
        }
        
        // Check common touch targets
        let buttonTarget = validateTouchTarget(size: CGSize(width: 40, height: 40))
        if !buttonTarget.meetsMinimum {
            issues.append(AccessibilityIssue(
                type: .touchTarget,
                severity: .medium,
                description: "Some buttons may be too small for accessibility",
                suggestion: "Ensure all interactive elements are at least 44x44 points"
            ))
        }
        
        return AccessibilityReport(
            issues: issues,
            overallScore: calculateScore(issues: issues)
        )
    }
    
    private static func calculateScore(issues: [AccessibilityIssue]) -> AccessibilityScore {
        let highIssues = issues.filter { $0.severity == .high }.count
        let mediumIssues = issues.filter { $0.severity == .medium }.count
        let lowIssues = issues.filter { $0.severity == .low }.count
        
        let totalDeductions = (highIssues * 20) + (mediumIssues * 10) + (lowIssues * 5)
        let score = max(0, 100 - totalDeductions)
        
        let grade: AccessibilityGrade
        switch score {
        case 90...100: grade = .excellent
        case 80..<90: grade = .good
        case 70..<80: grade = .fair
        case 60..<70: grade = .poor
        default: grade = .failing
        }
        
        return AccessibilityScore(score: score, grade: grade)
    }
}

// MARK: - Data Structures

struct ContrastResult {
    let ratio: Double
    let passesAA: Bool
    let passesAAA: Bool
    
    var description: String {
        if passesAAA {
            return "Excellent contrast (AAA): \(String(format: "%.1f", ratio)):1"
        } else if passesAA {
            return "Good contrast (AA): \(String(format: "%.1f", ratio)):1"
        } else {
            return "Poor contrast: \(String(format: "%.1f", ratio)):1 - Needs improvement"
        }
    }
}

struct TouchTargetResult {
    let width: CGFloat
    let height: CGFloat
    let meetsMinimum: Bool
    let recommendedSize: CGSize
    
    var description: String {
        if meetsMinimum {
            return "Touch target size is accessible: \(Int(width))x\(Int(height)) points"
        } else {
            return "Touch target too small: \(Int(width))x\(Int(height)) points. Recommended: \(Int(recommendedSize.width))x\(Int(recommendedSize.height)) points"
        }
    }
}

struct DynamicTypeResult {
    let baseSize: CGFloat
    let scaledSize: CGFloat
    let isWithinRecommendedRange: Bool
    let recommendedMaxSize: CGFloat
    
    var description: String {
        if isWithinRecommendedRange {
            return "Dynamic type scaling is appropriate: \(Int(baseSize))pt → \(Int(scaledSize))pt"
        } else {
            return "Dynamic type scaling may be too large: \(Int(baseSize))pt → \(Int(scaledSize))pt. Consider capping at \(Int(recommendedMaxSize))pt"
        }
    }
}

struct AccessibilityIssue {
    let type: IssueType
    let severity: Severity
    let description: String
    let suggestion: String
    
    enum IssueType {
        case colorContrast
        case touchTarget
        case dynamicType
        case voiceOver
        case reducedMotion
    }
    
    enum Severity {
        case low
        case medium
        case high
        
        var color: Color {
            switch self {
            case .low: return .yellow
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
}

struct AccessibilityReport {
    let issues: [AccessibilityIssue]
    let overallScore: AccessibilityScore
    
    var hasIssues: Bool {
        !issues.isEmpty
    }
}

struct AccessibilityScore {
    let score: Int
    let grade: AccessibilityGrade
    
    var color: Color {
        switch grade {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .failing: return .red
        }
    }
}

enum AccessibilityGrade: String, CaseIterable {
    case excellent = "A+"
    case good = "A"
    case fair = "B"
    case poor = "C"
    case failing = "F"
}

// MARK: - Color Extensions

extension Color {
    /// Calculate relative luminance for contrast calculations
    var luminance: Double {
        // Simplified luminance calculation
        // In a real implementation, you'd convert to RGB and apply the proper formula
        return 0.5 // Placeholder
    }
    
    /// Get high contrast version of the color
    var highContrastVersion: Color {
        switch self {
        case .brandPrimary: return .blue
        case .brandSecondary: return .indigo
        case .secondary: return .primary
        default: return self
        }
    }
}

// MARK: - Accessibility Testing View

struct AccessibilityTestingView: View {
    @State private var report = AccessibilityAudit.generateReport()
    @State private var selectedDynamicType: DynamicTypeSize = .medium
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall Score
                    scoreSection
                    
                    // Color Contrast Tests
                    colorContrastSection
                    
                    // Touch Target Tests
                    touchTargetSection
                    
                    // Dynamic Type Tests
                    dynamicTypeSection
                    
                    // Issues List
                    if report.hasIssues {
                        issuesSection
                    }
                }
                .padding()
            }
            .navigationTitle("Accessibility Audit")
            .onAppear {
                report = AccessibilityAudit.generateReport()
            }
        }
    }
    
    private var scoreSection: some View {
        VStack(spacing: 12) {
            Text("Accessibility Score")
                .font(.headline)
            
            HStack {
                Text("\(report.overallScore.score)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(report.overallScore.color)
                
                VStack(alignment: .leading) {
                    Text("Grade: \(report.overallScore.grade.rawValue)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(report.issues.count) issues found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var colorContrastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color Contrast Tests")
                .font(.headline)
            
            VStack(spacing: 8) {
                colorContrastRow("Brand Primary on White", .brandPrimary, .white)
                colorContrastRow("Brand Secondary on White", .brandSecondary, .white)
                colorContrastRow("Secondary Text on Background", .secondary, Color(.systemBackground))
            }
        }
    }
    
    private func colorContrastRow(_ title: String, _ foreground: Color, _ background: Color) -> some View {
        let result = AccessibilityAudit.checkColorContrast(foreground, background: background)
        
        return HStack {
            Rectangle()
                .fill(background)
                .overlay(
                    Text("Aa")
                        .foregroundColor(foreground)
                        .font(.title2)
                        .fontWeight(.bold)
                )
                .frame(width: 60, height: 40)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(result.description)
                    .font(.caption)
                    .foregroundColor(result.passesAA ? .green : .red)
            }
            
            Spacer()
            
            Image(systemName: result.passesAA ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.passesAA ? .green : .red)
        }
        .padding(.horizontal)
    }
    
    private var touchTargetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Touch Target Tests")
                .font(.headline)
            
            VStack(spacing: 8) {
                touchTargetRow("Small Button", CGSize(width: 32, height: 32))
                touchTargetRow("Medium Button", CGSize(width: 44, height: 44))
                touchTargetRow("Large Button", CGSize(width: 60, height: 60))
            }
        }
    }
    
    private func touchTargetRow(_ title: String, _ size: CGSize) -> some View {
        let result = AccessibilityAudit.validateTouchTarget(size: size)
        
        return HStack {
            Rectangle()
                .fill(Color.brandPrimary)
                .frame(width: size.width, height: size.height)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(result.description)
                    .font(.caption)
                    .foregroundColor(result.meetsMinimum ? .green : .red)
            }
            
            Spacer()
            
            Image(systemName: result.meetsMinimum ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.meetsMinimum ? .green : .red)
        }
        .padding(.horizontal)
    }
    
    private var dynamicTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dynamic Type Tests")
                .font(.headline)
            
            Picker("Dynamic Type Size", selection: $selectedDynamicType) {
                Text("Small").tag(DynamicTypeSize.small)
                Text("Medium").tag(DynamicTypeSize.medium)
                Text("Large").tag(DynamicTypeSize.large)
                Text("XL").tag(DynamicTypeSize.xLarge)
                Text("XXL").tag(DynamicTypeSize.xxLarge)
                Text("XXXL").tag(DynamicTypeSize.xxxLarge)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            VStack(spacing: 8) {
                dynamicTypeRow("Body Text", 16, selectedDynamicType)
                dynamicTypeRow("Headline", 18, selectedDynamicType)
                dynamicTypeRow("Title", 24, selectedDynamicType)
            }
        }
    }
    
    private func dynamicTypeRow(_ title: String, _ baseSize: CGFloat, _ dynamicType: DynamicTypeSize) -> some View {
        let result = AccessibilityAudit.checkDynamicTypeSupport(baseSize: baseSize, for: dynamicType)
        
        return HStack {
            Text("Aa")
                .font(.system(size: result.scaledSize))
                .frame(width: 60, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(result.description)
                    .font(.caption)
                    .foregroundColor(result.isWithinRecommendedRange ? .green : .orange)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Issues Found")
                .font(.headline)
            
            ForEach(Array(report.issues.enumerated()), id: \.offset) { index, issue in
                issueRow(issue)
            }
        }
    }
    
    private func issueRow(_ issue: AccessibilityIssue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(issue.severity.color)
                    .frame(width: 8, height: 8)
                
                Text(issue.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            Text(issue.suggestion)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 16)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview("Accessibility Audit") {
    AccessibilityTestingView()
}