import SwiftUI
import Foundation

/// User experience optimization system for calendar features
class CalendarUXOptimizer {
    static let shared = CalendarUXOptimizer()
    
    @Published var optimizations: [UXOptimization] = []
    @Published var userFeedback: [UserFeedback] = []
    
    private init() {
        loadOptimizations()
    }
    
    // MARK: - UX Optimizations
    
    private func loadOptimizations() {
        optimizations = [
            UXOptimization(
                id: "UX-001",
                title: "Improved Event Creation Flow",
                description: "Streamlined event creation with smart defaults and better validation",
                category: .workflow,
                impact: .high,
                status: .implemented,
                implementedDate: Date().addingTimeInterval(-86400 * 14),
                metrics: UXMetrics(
                    completionRate: 0.92,
                    timeToComplete: 45.0,
                    userSatisfaction: 4.3,
                    errorRate: 0.08
                )
            ),
            
            UXOptimization(
                id: "UX-002",
                title: "Enhanced Calendar Navigation",
                description: "Improved month/week navigation with better visual feedback",
                category: .navigation,
                impact: .medium,
                status: .implemented,
                implementedDate: Date().addingTimeInterval(-86400 * 10),
                metrics: UXMetrics(
                    completionRate: 0.89,
                    timeToComplete: 12.0,
                    userSatisfaction: 4.1,
                    errorRate: 0.05
                )
            ),
            
            UXOptimization(
                id: "UX-003",
                title: "Smart Event Suggestions",
                description: "AI-powered event suggestions based on user patterns",
                category: .intelligence,
                impact: .high,
                status: .planned,
                implementedDate: nil,
                metrics: nil
            ),
            
            UXOptimization(
                id: "UX-004",
                title: "Contextual Help System",
                description: "In-app help that appears when users need it most",
                category: .help,
                impact: .medium,
                status: .inProgress,
                implementedDate: nil,
                metrics: nil
            ),
            
            UXOptimization(
                id: "UX-005",
                title: "Accessibility Improvements",
                description: "Enhanced VoiceOver support and keyboard navigation",
                category: .accessibility,
                impact: .high,
                status: .implemented,
                implementedDate: Date().addingTimeInterval(-86400 * 7),
                metrics: UXMetrics(
                    completionRate: 0.85,
                    timeToComplete: 60.0,
                    userSatisfaction: 4.5,
                    errorRate: 0.12
                )
            )
        ]
    }
    
    // MARK: - User Feedback Collection
    
    func collectFeedback(_ feedback: UserFeedback) {
        userFeedback.append(feedback)
        
        // Analyze feedback for optimization opportunities
        analyzeFeedbackForOptimizations(feedback)
    }
    
    private func analyzeFeedbackForOptimizations(_ feedback: UserFeedback) {
        // Look for patterns in feedback that suggest UX improvements
        
        if feedback.rating < 3.0 {
            // Low rating - investigate for optimization opportunities
            let optimization = UXOptimization(
                id: "UX-AUTO-\(UUID().uuidString.prefix(8))",
                title: "Address User Concern: \(feedback.category.rawValue)",
                description: "Based on user feedback: \(feedback.comment ?? "Low satisfaction rating")",
                category: .feedback,
                impact: feedback.rating < 2.0 ? .high : .medium,
                status: .identified,
                implementedDate: nil,
                metrics: nil
            )
            
            optimizations.append(optimization)
        }
    }
    
    // MARK: - Performance Monitoring
    
    func trackUserAction(_ action: UserAction, duration: TimeInterval, success: Bool) {
        let actionData = UserActionData(
            action: action,
            duration: duration,
            success: success,
            timestamp: Date()
        )
        
        // Store action data for analysis
        storeActionData(actionData)
        
        // Check for performance issues
        if duration > action.expectedDuration * 2 {
            // Action took too long - potential optimization opportunity
            let optimization = UXOptimization(
                id: "UX-PERF-\(UUID().uuidString.prefix(8))",
                title: "Optimize \(action.rawValue) Performance",
                description: "Action taking \(String(format: "%.1f", duration))s (expected: \(String(format: "%.1f", action.expectedDuration))s)",
                category: .performance,
                impact: .medium,
                status: .identified,
                implementedDate: nil,
                metrics: nil
            )
            
            optimizations.append(optimization)
        }
    }
    
    private func storeActionData(_ data: UserActionData) {
        // In a real app, this would store to analytics service
        print("📊 Action tracked: \(data.action.rawValue) - \(String(format: "%.2f", data.duration))s")
    }
    
    // MARK: - A/B Testing
    
    func shouldShowFeature(_ feature: ExperimentalFeature) -> Bool {
        // Simple A/B testing logic
        let userId = getCurrentUserId()
        let hash = abs(userId.hashValue)
        let bucket = hash % 100
        
        return bucket < feature.rolloutPercentage
    }
    
    private func getCurrentUserId() -> String {
        // Get current user ID from app state
        return "demo-user-id"
    }
    
    // MARK: - UX Metrics Analysis
    
    func generateUXReport() -> UXReport {
        let implementedOptimizations = optimizations.filter { $0.status == .implemented }
        
        let averageCompletionRate = implementedOptimizations.compactMap { $0.metrics?.completionRate }.reduce(0, +) / Double(implementedOptimizations.count)
        let averageTimeToComplete = implementedOptimizations.compactMap { $0.metrics?.timeToComplete }.reduce(0, +) / Double(implementedOptimizations.count)
        let averageUserSatisfaction = implementedOptimizations.compactMap { $0.metrics?.userSatisfaction }.reduce(0, +) / Double(implementedOptimizations.count)
        let averageErrorRate = implementedOptimizations.compactMap { $0.metrics?.errorRate }.reduce(0, +) / Double(implementedOptimizations.count)
        
        let recentFeedback = userFeedback.filter { $0.date > Date().addingTimeInterval(-86400 * 30) }
        let averageFeedbackRating = recentFeedback.map { $0.rating }.reduce(0, +) / Double(recentFeedback.count)
        
        return UXReport(
            totalOptimizations: optimizations.count,
            implementedOptimizations: implementedOptimizations.count,
            averageCompletionRate: averageCompletionRate,
            averageTimeToComplete: averageTimeToComplete,
            averageUserSatisfaction: averageUserSatisfaction,
            averageErrorRate: averageErrorRate,
            recentFeedbackCount: recentFeedback.count,
            averageFeedbackRating: averageFeedbackRating,
            topIssues: getTopIssues(),
            recommendations: getRecommendations()
        )
    }
    
    private func getTopIssues() -> [String] {
        let lowRatingFeedback = userFeedback.filter { $0.rating < 3.0 }
        let issueCategories = Dictionary(grouping: lowRatingFeedback, by: { $0.category })
        
        return issueCategories.sorted { $0.value.count > $1.value.count }
            .prefix(3)
            .map { "\($0.key.rawValue) (\($0.value.count) reports)" }
    }
    
    private func getRecommendations() -> [String] {
        var recommendations: [String] = []
        
        // Analyze metrics for recommendations
        let implementedOptimizations = optimizations.filter { $0.status == .implemented }
        
        if let lowCompletionOptimization = implementedOptimizations.min(by: { ($0.metrics?.completionRate ?? 1.0) < ($1.metrics?.completionRate ?? 1.0) }) {
            if let completionRate = lowCompletionOptimization.metrics?.completionRate, completionRate < 0.8 {
                recommendations.append("Improve completion rate for \(lowCompletionOptimization.title)")
            }
        }
        
        if let slowOptimization = implementedOptimizations.max(by: { ($0.metrics?.timeToComplete ?? 0.0) < ($1.metrics?.timeToComplete ?? 0.0) }) {
            if let timeToComplete = slowOptimization.metrics?.timeToComplete, timeToComplete > 60.0 {
                recommendations.append("Optimize performance for \(slowOptimization.title)")
            }
        }
        
        let recentLowRatingFeedback = userFeedback.filter { $0.rating < 3.0 && $0.date > Date().addingTimeInterval(-86400 * 7) }
        if recentLowRatingFeedback.count > 5 {
            recommendations.append("Address recent user satisfaction concerns")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

struct UXOptimization: Identifiable {
    let id: String
    let title: String
    let description: String
    let category: UXCategory
    let impact: UXImpact
    var status: UXStatus
    let implementedDate: Date?
    let metrics: UXMetrics?
}

enum UXCategory: String, CaseIterable {
    case workflow = "Workflow"
    case navigation = "Navigation"
    case intelligence = "Intelligence"
    case help = "Help"
    case accessibility = "Accessibility"
    case performance = "Performance"
    case feedback = "Feedback"
    
    var icon: String {
        switch self {
        case .workflow: return "arrow.right.circle"
        case .navigation: return "location"
        case .intelligence: return "brain.head.profile"
        case .help: return "questionmark.circle"
        case .accessibility: return "accessibility"
        case .performance: return "speedometer"
        case .feedback: return "message"
        }
    }
}

enum UXImpact: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}

enum UXStatus: String, CaseIterable {
    case identified = "Identified"
    case planned = "Planned"
    case inProgress = "In Progress"
    case implemented = "Implemented"
    case validated = "Validated"
    
    var color: Color {
        switch self {
        case .identified: return .gray
        case .planned: return .blue
        case .inProgress: return .orange
        case .implemented: return .green
        case .validated: return .purple
        }
    }
}

struct UXMetrics {
    let completionRate: Double // 0.0 to 1.0
    let timeToComplete: TimeInterval // seconds
    let userSatisfaction: Double // 1.0 to 5.0
    let errorRate: Double // 0.0 to 1.0
}

struct UserFeedback: Identifiable {
    let id = UUID()
    let category: FeedbackCategory
    let rating: Double // 1.0 to 5.0
    let comment: String?
    let date: Date
    let userId: String
}

enum FeedbackCategory: String, CaseIterable {
    case eventCreation = "Event Creation"
    case eventEditing = "Event Editing"
    case navigation = "Navigation"
    case sync = "Sync"
    case performance = "Performance"
    case accessibility = "Accessibility"
    case general = "General"
}

enum UserAction: String, CaseIterable {
    case createEvent = "Create Event"
    case editEvent = "Edit Event"
    case deleteEvent = "Delete Event"
    case navigateCalendar = "Navigate Calendar"
    case syncCalendar = "Sync Calendar"
    case viewEventDetails = "View Event Details"
    
    var expectedDuration: TimeInterval {
        switch self {
        case .createEvent: return 30.0
        case .editEvent: return 20.0
        case .deleteEvent: return 5.0
        case .navigateCalendar: return 2.0
        case .syncCalendar: return 10.0
        case .viewEventDetails: return 3.0
        }
    }
}

struct UserActionData {
    let action: UserAction
    let duration: TimeInterval
    let success: Bool
    let timestamp: Date
}

enum ExperimentalFeature: String, CaseIterable {
    case smartSuggestions = "Smart Suggestions"
    case advancedFiltering = "Advanced Filtering"
    case voiceInput = "Voice Input"
    
    var rolloutPercentage: Int {
        switch self {
        case .smartSuggestions: return 25 // 25% of users
        case .advancedFiltering: return 50 // 50% of users
        case .voiceInput: return 10 // 10% of users
        }
    }
}

struct UXReport {
    let totalOptimizations: Int
    let implementedOptimizations: Int
    let averageCompletionRate: Double
    let averageTimeToComplete: TimeInterval
    let averageUserSatisfaction: Double
    let averageErrorRate: Double
    let recentFeedbackCount: Int
    let averageFeedbackRating: Double
    let topIssues: [String]
    let recommendations: [String]
}

// MARK: - UX Dashboard View

struct CalendarUXDashboardView: View {
    @StateObject private var uxOptimizer = CalendarUXOptimizer.shared
    @State private var selectedCategory: UXCategory?
    @State private var showFeedbackForm = false
    @State private var uxReport: UXReport?
    
    var filteredOptimizations: [UXOptimization] {
        if let category = selectedCategory {
            return uxOptimizer.optimizations.filter { $0.category == category }
        }
        return uxOptimizer.optimizations
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // UX Metrics Summary
                    if let report = uxReport {
                        UXMetricsSummaryView(report: report)
                    }
                    
                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            Button("All") {
                                selectedCategory = nil
                            }
                            .buttonStyle(.bordered)
                            .background(selectedCategory == nil ? Color.blue : Color.clear)
                            
                            ForEach(UXCategory.allCases, id: \.self) { category in
                                Button(category.rawValue) {
                                    selectedCategory = category
                                }
                                .buttonStyle(.bordered)
                                .background(selectedCategory == category ? Color.blue : Color.clear)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Optimizations List
                    LazyVStack(spacing: 12) {
                        ForEach(filteredOptimizations) { optimization in
                            UXOptimizationCard(optimization: optimization)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Recent Feedback
                    if !uxOptimizer.userFeedback.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Feedback")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(uxOptimizer.userFeedback.prefix(5)) { feedback in
                                    UserFeedbackCard(feedback: feedback)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("UX Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Provide Feedback") {
                            showFeedbackForm = true
                        }
                        
                        Button("Generate Report") {
                            generateReport()
                        }
                        
                        Button("Export Data") {
                            exportUXData()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showFeedbackForm) {
                UserFeedbackFormView { feedback in
                    uxOptimizer.collectFeedback(feedback)
                }
            }
            .task {
                generateReport()
            }
        }
    }
    
    private func generateReport() {
        uxReport = uxOptimizer.generateUXReport()
    }
    
    private func exportUXData() {
        // Export UX data functionality
        CalendarHapticManager.shared.lightImpact()
    }
}

struct UXMetricsSummaryView: View {
    let report: UXReport
    
    var body: some View {
        VStack(spacing: 16) {
            Text("UX Metrics Summary")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(
                    title: "Completion Rate",
                    value: String(format: "%.1f%%", report.averageCompletionRate * 100),
                    color: report.averageCompletionRate > 0.8 ? .green : .orange
                )
                
                MetricCard(
                    title: "Avg. Time",
                    value: String(format: "%.1fs", report.averageTimeToComplete),
                    color: report.averageTimeToComplete < 30 ? .green : .orange
                )
                
                MetricCard(
                    title: "Satisfaction",
                    value: String(format: "%.1f/5.0", report.averageUserSatisfaction),
                    color: report.averageUserSatisfaction > 4.0 ? .green : .orange
                )
                
                MetricCard(
                    title: "Error Rate",
                    value: String(format: "%.1f%%", report.averageErrorRate * 100),
                    color: report.averageErrorRate < 0.1 ? .green : .red
                )
            }
            
            if !report.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendations")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(report.recommendations, id: \.self) { recommendation in
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.yellow)
                            
                            Text(recommendation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct UXOptimizationCard: View {
    let optimization: UXOptimization
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: optimization.category.icon)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(optimization.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(optimization.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(optimization.status.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(optimization.status.color.opacity(0.2))
                        .foregroundColor(optimization.status.color)
                        .cornerRadius(4)
                    
                    Text(optimization.impact.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(optimization.impact.color.opacity(0.2))
                        .foregroundColor(optimization.impact.color)
                        .cornerRadius(4)
                }
            }
            
            Text(optimization.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let metrics = optimization.metrics {
                HStack {
                    Text("Completion: \(String(format: "%.1f%%", metrics.completionRate * 100))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Satisfaction: \(String(format: "%.1f/5", metrics.userSatisfaction))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct UserFeedbackCard: View {
    let feedback: UserFeedback
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(feedback.category.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(feedback.rating) ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                if let comment = feedback.comment {
                    Text(comment)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(RelativeDateTimeFormatter().localizedString(for: feedback.date, relativeTo: Date()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct UserFeedbackFormView: View {
    let onSubmit: (UserFeedback) -> Void
    
    @State private var selectedCategory: FeedbackCategory = .general
    @State private var rating: Double = 5.0
    @State private var comment: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Rating") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How would you rate this feature?")
                            .font(.subheadline)
                        
                        HStack {
                            ForEach(1...5, id: \.self) { star in
                                Button(action: { rating = Double(star) }) {
                                    Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                        .font(.title2)
                                        .foregroundColor(.yellow)
                                }
                            }
                            
                            Spacer()
                            
                            Text("\(Int(rating))/5")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Comments") {
                    TextField("Tell us more about your experience...", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        let feedback = UserFeedback(
                            category: selectedCategory,
                            rating: rating,
                            comment: comment.isEmpty ? nil : comment,
                            date: Date(),
                            userId: "demo-user"
                        )
                        
                        onSubmit(feedback)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CalendarUXDashboardView()
        .previewEnvironment()
}