import SwiftUI

/// Demo view to showcase environment object error handling UI components
/// This view demonstrates all the error handling UI components and their interactions
struct EnvironmentObjectErrorDemoView: View {
    @StateObject private var errorHandler = EnvironmentObjectErrorHandler.shared
    @StateObject private var toastManager = EnvironmentObjectToastManager.shared
    
    @State private var selectedError: EnvironmentObjectError?
    @State private var showErrorView = false
    @State private var demoContext = EnvironmentErrorContext.default
    @State private var showStatistics = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Error Simulation Section
                    errorSimulationSection
                    
                    // Toast Notification Section
                    toastNotificationSection
                    
                    // Error Handler Section
                    errorHandlerSection
                    
                    // Statistics Section
                    statisticsSection
                    
                    // Context Configuration Section
                    contextConfigurationSection
                }
                .padding()
            }
            .navigationTitle("Environment Error Demo")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showErrorView) {
                errorViewSheet
            }
            .sheet(isPresented: $showStatistics) {
                statisticsSheet
            }
            .withEnvironmentObjectToast()
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Environment Object Error Handling")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Demonstrates error handling UI components for environment object issues")
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
    
    private var errorSimulationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Error Simulation")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Simulate different types of environment object errors")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ErrorSimulationButton(
                    title: "Missing AppState",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                ) {
                    simulateMissingAppState()
                }
                
                ErrorSimulationButton(
                    title: "Invalid State",
                    icon: "gear.badge.xmark",
                    color: .red
                ) {
                    simulateInvalidState()
                }
                
                ErrorSimulationButton(
                    title: "Dependency Issue",
                    icon: "link.badge.plus",
                    color: .purple
                ) {
                    simulateDependencyIssue()
                }
                
                ErrorSimulationButton(
                    title: "Fallback Failed",
                    icon: "xmark.circle.fill",
                    color: .red
                ) {
                    simulateFallbackFailed()
                }
            }
            
            Button("Show Error View") {
                selectedError = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
                showErrorView = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private var toastNotificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Toast Notifications")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Non-intrusive notifications for environment issues")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ToastDemoButton(
                    title: "Missing Environment",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                ) {
                    toastManager.showMissingEnvironment(type: "AppState", viewName: "DemoView")
                }
                
                ToastDemoButton(
                    title: "Fallback Active",
                    icon: "gear.badge",
                    color: .blue
                ) {
                    toastManager.showFallbackActive(type: "AppState")
                }
                
                ToastDemoButton(
                    title: "State Inconsistent",
                    icon: "exclamationmark.circle.fill",
                    color: .red
                ) {
                    toastManager.showStateInconsistent(details: "Navigation path corrupted")
                }
                
                ToastDemoButton(
                    title: "Dependency Issue",
                    icon: "link.badge.plus",
                    color: .purple
                ) {
                    toastManager.showDependencyIssue(missing: ["AppState", "NavigationManager"])
                }
            }
            
            Button("Recovery Sequence") {
                toastManager.showRecoverySequence(initialAction: .refreshEnvironment) { success in
                    print("Recovery sequence completed: \(success)")
                }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private var errorHandlerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Error Handler")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Automatic error detection and recovery")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Active Errors:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(errorHandler.hasActiveErrors ? "Yes" : "None")
                        .foregroundColor(errorHandler.hasActiveErrors ? .red : .green)
                }
                
                HStack {
                    Text("Recovery History:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(errorHandler.recoveryHistory.count) attempts")
                        .foregroundColor(.secondary)
                }
                
                if errorHandler.isRecovering {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Recovery in progress...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            HStack(spacing: 12) {
                Button("Trigger Auto Recovery") {
                    triggerAutoRecovery()
                }
                .buttonStyle(.bordered)
                
                Button("Manual Recovery") {
                    triggerManualRecovery()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Statistics")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View Details") {
                    showStatistics = true
                }
                .font(.subheadline)
                .foregroundColor(.brandPrimary)
            }
            
            let stats = errorHandler.statistics
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                EnvironmentStatisticCard(
                    title: "Total Attempts",
                    value: "\(stats.totalRecoveryAttempts)",
                    icon: "arrow.clockwise",
                    color: .blue
                )
                
                EnvironmentStatisticCard(
                    title: "Success Rate",
                    value: String(format: "%.1f%%", stats.successRate),
                    icon: "checkmark.circle.fill",
                    color: stats.isHealthy ? .green : .orange
                )
                
                EnvironmentStatisticCard(
                    title: "Failed Recoveries",
                    value: "\(stats.failedRecoveries)",
                    icon: "xmark.circle.fill",
                    color: .red
                )
                
                EnvironmentStatisticCard(
                    title: "Health Status",
                    value: stats.isHealthy ? "Healthy" : "Needs Attention",
                    icon: stats.isHealthy ? "heart.fill" : "heart.slash.fill",
                    color: stats.isHealthy ? .green : .red
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private var contextConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Context Configuration")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Toggle("Show Technical Details", isOn: Binding(
                    get: { demoContext.showTechnicalDetails },
                    set: { newValue in
                        demoContext = EnvironmentErrorContext(
                            viewName: demoContext.viewName,
                            showTechnicalDetails: newValue,
                            allowRecovery: demoContext.allowRecovery
                        )
                    }
                ))
                
                Toggle("Allow Recovery", isOn: Binding(
                    get: { demoContext.allowRecovery },
                    set: { newValue in
                        demoContext = EnvironmentErrorContext(
                            viewName: demoContext.viewName,
                            showTechnicalDetails: demoContext.showTechnicalDetails,
                            allowRecovery: newValue
                        )
                    }
                ))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    // MARK: - Sheet Views
    
    private var errorViewSheet: some View {
        NavigationView {
            VStack {
                if let error = selectedError {
                    EnvironmentObjectErrorView(
                        error: error,
                        context: demoContext,
                        onRecoveryAction: { action in
                            print("Recovery action executed: \(action)")
                            Task {
                                _ = await errorHandler.executeRecoveryAction(action, for: error)
                            }
                        },
                        onDismiss: {
                            showErrorView = false
                        }
                    )
                } else {
                    Text("No error selected")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Error View Demo")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                showErrorView = false
            })
        }
    }
    
    private var statisticsSheet: some View {
        NavigationView {
            StatisticsDetailView(statistics: errorHandler.statistics)
                .navigationTitle("Error Statistics")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Done") {
                    showStatistics = false
                })
        }
    }
    
    // MARK: - Actions
    
    private func simulateMissingAppState() {
        let error = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
        errorHandler.handleError(error, in: "DemoView")
    }
    
    private func simulateInvalidState() {
        let error = EnvironmentObjectError.invalidEnvironmentObjectState(
            type: "AppState",
            reason: "Navigation state is corrupted"
        )
        errorHandler.handleError(error, in: "DemoView")
    }
    
    private func simulateDependencyIssue() {
        let error = EnvironmentObjectError.dependencyInjectionFailure(
            "Multiple dependencies missing: AppState, NavigationManager"
        )
        errorHandler.handleError(error, in: "DemoView")
    }
    
    private func simulateFallbackFailed() {
        let error = EnvironmentObjectError.fallbackCreationFailed(
            type: "AppState",
            underlyingError: NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        )
        errorHandler.handleError(error, in: "DemoView")
    }
    
    private func triggerAutoRecovery() {
        let error = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
        errorHandler.handleError(error, in: "DemoView", context: ["autoRecovery": true])
    }
    
    private func triggerManualRecovery() {
        let error = EnvironmentObjectError.dependencyInjectionFailure("Manual recovery test")
        selectedError = error
        errorHandler.handleError(error, in: "DemoView", context: ["manualRecovery": true])
    }
}

// MARK: - Supporting Views

struct ErrorSimulationButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

struct ToastDemoButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

struct EnvironmentStatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

struct StatisticsDetailView: View {
    let statistics: EnvironmentErrorStatistics
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Overview Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Overview")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        EnvironmentStatisticRow(label: "Total Recovery Attempts", value: "\(statistics.totalRecoveryAttempts)")
                        EnvironmentStatisticRow(label: "Successful Recoveries", value: "\(statistics.successfulRecoveries)")
                        EnvironmentStatisticRow(label: "Failed Recoveries", value: "\(statistics.failedRecoveries)")
                        EnvironmentStatisticRow(label: "Success Rate", value: String(format: "%.1f%%", statistics.successRate))
                        EnvironmentStatisticRow(label: "Average Recovery Time", value: String(format: "%.1fs", statistics.averageRecoveryTime))
                    }
                }
                
                // Errors by Type Section
                if !statistics.errorsByType.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Errors by Type")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            ForEach(Array(statistics.errorsByType.keys.sorted()), id: \.self) { errorType in
                                EnvironmentStatisticRow(
                                    label: errorType.capitalized,
                                    value: "\(statistics.errorsByType[errorType] ?? 0)"
                                )
                            }
                        }
                    }
                }
                
                // Actions by Type Section
                if !statistics.actionsByType.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Actions by Type")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            ForEach(Array(statistics.actionsByType.keys.sorted(by: { $0.title < $1.title })), id: \.self) { action in
                                EnvironmentStatisticRow(
                                    label: action.title,
                                    value: "\(statistics.actionsByType[action] ?? 0)"
                                )
                            }
                        }
                    }
                }
                
                // Most Common Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Most Common")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        EnvironmentStatisticRow(
                            label: "Most Common Error",
                            value: statistics.mostCommonError?.capitalized ?? "None"
                        )
                        EnvironmentStatisticRow(
                            label: "Most Successful Action",
                            value: statistics.mostSuccessfulAction?.title ?? "None"
                        )
                    }
                }
                
                // Health Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Health Status")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: statistics.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(statistics.isHealthy ? .green : .orange)
                        
                        Text(statistics.isHealthy ? "System is healthy" : "System needs attention")
                            .fontWeight(.medium)
                            .foregroundColor(statistics.isHealthy ? .green : .orange)
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((statistics.isHealthy ? Color.green : Color.orange).opacity(0.1))
                    )
                }
            }
            .padding()
        }
    }
}

struct EnvironmentStatisticRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("Environment Object Error Demo") {
    EnvironmentObjectErrorDemoView()
}