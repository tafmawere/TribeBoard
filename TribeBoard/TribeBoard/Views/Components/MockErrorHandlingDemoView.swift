import SwiftUI

/// Demo view showcasing comprehensive mock error handling system
struct MockErrorHandlingDemoView: View {
    
    @StateObject private var errorCoordinator = MockErrorHandlingCoordinator()
    @State private var selectedCategory: MockErrorCategory = .network
    @State private var selectedScenario: MockErrorScenario = .networkOutage
    @State private var showingErrorDetails = false
    @State private var showingRecoveryInsights = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Error Generation Controls
                    errorGenerationSection
                    
                    // Error Scenarios
                    errorScenariosSection
                    
                    // Current Error Display
                    if let currentError = errorCoordinator.currentError {
                        currentErrorSection(currentError)
                    }
                    
                    // Error Statistics
                    errorStatisticsSection
                    
                    // Recovery Insights
                    recoveryInsightsSection
                    
                    // Demo Controls
                    demoControlsSection
                }
                .padding()
            }
            .navigationTitle("Error Handling Demo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Run Full Demo") {
                            errorCoordinator.runErrorDemo()
                        }
                        
                        Button("Reset Tracking") {
                            errorCoordinator.resetErrorTracking()
                        }
                        
                        Button(errorCoordinator.isErrorHandlingEnabled ? "Disable Errors" : "Enable Errors") {
                            errorCoordinator.setErrorHandlingEnabled(!errorCoordinator.isErrorHandlingEnabled)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingErrorDetails) {
            if let error = errorCoordinator.currentError {
                ErrorDetailsView(error: error, recoveryManager: errorCoordinator.getRecoveryManager())
            }
        }
        .sheet(isPresented: $showingRecoveryInsights) {
            RecoveryInsightsView(insights: errorCoordinator.getErrorHandlingInsights())
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Mock Error Handling System")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Test and demonstrate comprehensive error handling flows with realistic scenarios and recovery options.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Error Generation Section
    
    private var errorGenerationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generate Errors")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Category Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Error Category")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Category", selection: $selectedCategory) {
                    ForEach(MockErrorCategory.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                        }
                        .tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Generation Buttons
            HStack(spacing: 12) {
                Button("Generate Random") {
                    errorCoordinator.generateAndDisplayRandomError()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Generate \(selectedCategory.displayName)") {
                    let error = MockErrorGenerator().generateError(for: selectedCategory)
                    errorCoordinator.displayError(error)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - Error Scenarios Section
    
    private var errorScenariosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Error Scenarios")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Scenario Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Test Scenario")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Scenario", selection: $selectedScenario) {
                    ForEach(MockErrorScenario.allCases, id: \.self) { scenario in
                        VStack(alignment: .leading) {
                            Text(scenario.displayName)
                            Text(scenario.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(scenario)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Scenario Controls
            HStack(spacing: 12) {
                Button("Start Scenario") {
                    errorCoordinator.startErrorScenario(selectedScenario)
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Stop Scenario") {
                    errorCoordinator.stopErrorScenario()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            // Current Scenario Status
            if let currentScenario = errorCoordinator.errorGenerator.currentErrorScenario {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Running: \(currentScenario.displayName)")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - Current Error Section
    
    private func currentErrorSection(_ error: MockError) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Error")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Details") {
                    showingErrorDetails = true
                }
                .font(.caption)
                .buttonStyle(TertiaryButtonStyle())
            }
            
            // Enhanced Error Display
            EnhancedErrorStateView(
                error: error,
                recoveryManager: errorCoordinator.getRecoveryManager(),
                onDismiss: {
                    errorCoordinator.dismissCurrentError()
                }
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 2)
        )
    }
    
    // MARK: - Error Statistics Section
    
    private var errorStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Error Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let statistics = errorCoordinator.errorStatistics {
                VStack(spacing: 12) {
                    // Total Errors
                    StatisticRow(
                        title: "Total Errors",
                        value: "\(statistics.totalErrors)",
                        icon: "exclamationmark.triangle"
                    )
                    
                    // Errors by Category
                    if !statistics.errorsByCategory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("By Category")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(Array(statistics.errorsByCategory.keys), id: \.self) { category in
                                HStack {
                                    Image(systemName: category.icon)
                                        .foregroundColor(.secondary)
                                    
                                    Text(category.displayName)
                                        .font(.caption)
                                    
                                    Spacer()
                                    
                                    Text("\(statistics.errorsByCategory[category] ?? 0)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                    
                    // Average Errors Per Hour
                    StatisticRow(
                        title: "Avg/Hour",
                        value: String(format: "%.1f", statistics.averageErrorsPerHour),
                        icon: "clock"
                    )
                }
            } else {
                Text("No error statistics available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - Recovery Insights Section
    
    private var recoveryInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recovery Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingRecoveryInsights = true
                }
                .font(.caption)
                .buttonStyle(TertiaryButtonStyle())
            }
            
            let insights = errorCoordinator.getErrorHandlingInsights()
            
            if insights.isEmpty {
                Text("No insights available yet. Generate some errors to see recovery analysis.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(insights.prefix(3), id: \.message) { insight in
                        InsightRow(insight: insight)
                    }
                    
                    if insights.count > 3 {
                        Text("+ \(insights.count - 3) more insights")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - Demo Controls Section
    
    private var demoControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Demo Controls")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Button("Run Complete Error Demo") {
                    errorCoordinator.runErrorDemo()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                HStack(spacing: 12) {
                    Button("Export Data") {
                        let exportData = errorCoordinator.exportErrorData()
                        // In a real app, this would save or share the data
                        print("Exported error data: \(exportData.errors.count) errors")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button("Reset All") {
                        errorCoordinator.resetErrorTracking()
                    }
                    .buttonStyle(DestructiveButtonStyle())
                }
                
                Toggle("Error Handling Enabled", isOn: .init(
                    get: { errorCoordinator.isErrorHandlingEnabled },
                    set: { errorCoordinator.setErrorHandlingEnabled($0) }
                ))
                .toggleStyle(SwitchToggleStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Supporting Views

struct StatisticRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct InsightRow: View {
    let insight: MockRecoveryInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(insight.message)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(insight.recommendation)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Detail Views

struct ErrorDetailsView: View {
    let error: MockError
    let recoveryManager: MockErrorRecoveryManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Error Overview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Error Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: error.category.icon)
                                .font(.title3)
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading) {
                                Text(error.title)
                                    .font(.headline)
                                
                                Text(error.category.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(error.severity.displayName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red.opacity(0.2))
                                )
                        }
                        
                        Text(error.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Technical Information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Technical Information")
                            .font(.headline)
                        
                        DetailRow(icon: "tag", title: "Category", value: error.category.rawValue)
                        DetailRow(icon: "exclamationmark.triangle", title: "Type", value: error.type.rawValue)
                        DetailRow(icon: "gauge", title: "Severity", value: error.severity.rawValue)
                        DetailRow(icon: "arrow.clockwise", title: "Retryable", value: error.isRetryable ? "Yes" : "No")
                        DetailRow(icon: "clock", title: "Timestamp", value: DateFormatter.localizedString(from: error.timestamp, dateStyle: .short, timeStyle: .medium))
                    }
                    
                    Divider()
                    
                    // Recovery Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Recovery Actions")
                            .font(.headline)
                        
                        ForEach(error.recoveryActions, id: \.self) { action in
                            HStack {
                                Image(systemName: action.icon)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text(action.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Style: \(action.style)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Divider()
                    
                    // Context Information
                    if !error.context.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Context Information")
                                .font(.headline)
                            
                            ForEach(Array(error.context.keys.sorted()), id: \.self) { key in
                                DetailRow(icon: "info.circle", title: key, value: "\(error.context[key] ?? "N/A")")
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Error Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}



struct RecoveryInsightsView: View {
    let insights: [MockRecoveryInsight]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(insights, id: \.message) { insight in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(insight.message)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(insight.recommendation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let category = insight.category {
                            HStack {
                                Image(systemName: category.icon)
                                    .font(.caption2)
                                
                                Text(category.displayName)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Recovery Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MockErrorHandlingDemoView()
}