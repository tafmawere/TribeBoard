import SwiftUI

/// Component for displaying validation errors in a user-friendly format
struct ValidationErrorView: View {
    let errors: [ValidationError]
    
    var body: some View {
        if !errors.isEmpty {
            errorContent
        }
    }
    
    private var errorContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(sortedCategories, id: \.self) { category in
                categoryView(for: category)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(errorBackground)
    }
    
    private var sortedCategories: [ValidationErrorCategory] {
        groupedErrors.keys.sorted(by: { $0.displayName < $1.displayName })
    }
    
    private func categoryView(for category: ValidationErrorCategory) -> some View {
        Group {
            if let categoryErrors = groupedErrors[category], !categoryErrors.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(category.displayName)
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(.red)
                    
                    ForEach(Array(categoryErrors.enumerated()), id: \.offset) { _, error in
                        errorRow(for: error)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
        }
    }
    
    private func errorRow(for error: ValidationError) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(error.errorDescription ?? "Unknown error")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundColor(.red)
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var errorBackground: some View {
        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
            .fill(Color.red.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
    }
    
    /// Groups errors by category for better organization
    private var groupedErrors: [ValidationErrorCategory: [ValidationError]] {
        Dictionary(grouping: errors, by: \.category)
    }
}

#Preview("Validation Errors") {
    ValidationErrorView(errors: [
        .emptyRunName,
        .noStops,
        .emptyStopName(stopIndex: 1),
        .invalidStopDuration(stopIndex: 2)
    ])
    .padding()
}

#Preview("Single Error") {
    ValidationErrorView(errors: [
        .emptyRunName
    ])
    .padding()
}

#Preview("No Errors") {
    ValidationErrorView(errors: [])
        .padding()
}