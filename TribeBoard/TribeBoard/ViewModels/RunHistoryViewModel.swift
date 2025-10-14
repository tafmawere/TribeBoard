import SwiftUI
import Foundation

/// ViewModel for managing historical school run data with filtering, search, and sorting capabilities
@MainActor
class RunHistoryViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// All historical runs (completed and cancelled)
    @Published var historicalRuns: [SchoolRun] = []
    
    /// Filtered runs based on current search and filter criteria
    @Published var filteredRuns: [SchoolRun] = []
    
    /// Paginated filtered runs for display (performance optimization)
    @Published var paginatedFilteredRuns: [SchoolRun] = []
    
    /// Loading state for pagination
    @Published var isLoadingMore: Bool = false
    
    /// Loading state for async operations
    @Published var isLoading: Bool = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Search text for filtering runs
    @Published var searchText: String = "" {
        didSet {
            applyFiltersAndSort()
        }
    }
    
    /// Selected date range for filtering
    @Published var selectedDateRange: DateRange = .all {
        didSet {
            applyFiltersAndSort()
        }
    }
    
    /// Selected status filter
    @Published var selectedStatusFilter: StatusFilter = .all {
        didSet {
            applyFiltersAndSort()
        }
    }
    
    /// Current sort option
    @Published var sortOption: SortOption = .dateDescending {
        didSet {
            applyFiltersAndSort()
        }
    }
    
    // MARK: - Private Properties
    
    /// Manager for school run data operations
    private let manager: SchoolRunManager
    
    /// Pagination properties
    private let pageSize = 20
    private var currentPage = 0
    private var allFilteredRuns: [SchoolRun] = []
    
    // MARK: - Enums
    
    /// Date range options for filtering
    enum DateRange: String, CaseIterable, Identifiable {
        case all = "all"
        case lastWeek = "lastWeek"
        case lastMonth = "lastMonth"
        case lastThreeMonths = "lastThreeMonths"
        case lastYear = "lastYear"
        case custom = "custom"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .all: return "All Time"
            case .lastWeek: return "Last Week"
            case .lastMonth: return "Last Month"
            case .lastThreeMonths: return "Last 3 Months"
            case .lastYear: return "Last Year"
            case .custom: return "Custom Range"
            }
        }
        
        /// Get the date range for filtering
        func getDateRange() -> (start: Date?, end: Date?) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .all:
                return (nil, nil)
            case .lastWeek:
                let startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now)
                return (startDate, now)
            case .lastMonth:
                let startDate = calendar.date(byAdding: .month, value: -1, to: now)
                return (startDate, now)
            case .lastThreeMonths:
                let startDate = calendar.date(byAdding: .month, value: -3, to: now)
                return (startDate, now)
            case .lastYear:
                let startDate = calendar.date(byAdding: .year, value: -1, to: now)
                return (startDate, now)
            case .custom:
                // Custom range will be handled separately
                return (nil, nil)
            }
        }
    }
    
    /// Status filter options
    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "all"
        case completed = "completed"
        case cancelled = "cancelled"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .all: return "All Statuses"
            case .completed: return "Completed"
            case .cancelled: return "Cancelled"
            }
        }
        
        var runStatus: RunStatus? {
            switch self {
            case .all: return nil
            case .completed: return .completed
            case .cancelled: return .cancelled
            }
        }
    }
    
    /// Sort options for runs
    enum SortOption: String, CaseIterable, Identifiable {
        case dateDescending = "dateDesc"
        case dateAscending = "dateAsc"
        case titleAscending = "titleAsc"
        case titleDescending = "titleDesc"
        case durationAscending = "durationAsc"
        case durationDescending = "durationDesc"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .dateDescending: return "Date (Newest First)"
            case .dateAscending: return "Date (Oldest First)"
            case .titleAscending: return "Title (A-Z)"
            case .titleDescending: return "Title (Z-A)"
            case .durationAscending: return "Duration (Shortest First)"
            case .durationDescending: return "Duration (Longest First)"
            }
        }
    }
    
    // MARK: - Custom Date Range Properties
    
    /// Custom start date for filtering
    @Published var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    
    /// Custom end date for filtering
    @Published var customEndDate: Date = Date()
    
    // MARK: - Computed Properties
    
    /// Check if there are any historical runs
    var hasHistoricalRuns: Bool {
        !historicalRuns.isEmpty
    }
    
    /// Check if there are any filtered results
    var hasFilteredResults: Bool {
        !allFilteredRuns.isEmpty
    }
    
    /// Check if there are more runs to load
    var hasMoreRuns: Bool {
        paginatedFilteredRuns.count < allFilteredRuns.count
    }
    
    /// Total number of historical runs
    var totalHistoricalRuns: Int {
        historicalRuns.count
    }
    
    /// Number of filtered runs
    var filteredRunsCount: Int {
        allFilteredRuns.count
    }
    
    /// Check if any filters are active
    var hasActiveFilters: Bool {
        !searchText.isEmpty || 
        selectedDateRange != .all || 
        selectedStatusFilter != .all
    }
    
    /// Summary statistics for filtered runs (computed lazily for performance)
    var runStatistics: RunStatistics {
        let completed = allFilteredRuns.filter { $0.status == .completed }.count
        let cancelled = allFilteredRuns.filter { $0.status == .cancelled }.count
        let totalDuration = allFilteredRuns.reduce(0) { $0 + $1.estimatedDuration }
        let averageDuration = allFilteredRuns.isEmpty ? 0 : totalDuration / Double(allFilteredRuns.count)
        
        return RunStatistics(
            totalRuns: allFilteredRuns.count,
            completedRuns: completed,
            cancelledRuns: cancelled,
            totalDuration: totalDuration,
            averageDuration: averageDuration
        )
    }
    
    // MARK: - Initialization
    
    init(manager: SchoolRunManager? = nil) {
        if let manager = manager {
            self.manager = manager
        } else {
            self.manager = SchoolRunManager()
        }
        setupBindings()
        loadHistoricalRuns()
    }
    
    // MARK: - Public Methods
    
    /// Load historical runs from the manager
    func loadHistoricalRuns() {
        isLoading = true
        errorMessage = nil
        
        Task {
            // Load from manager
            await manager.loadFromStorage()
            
            await MainActor.run {
                // Get completed and cancelled runs
                self.historicalRuns = manager.runs.filter { run in
                    run.status == .completed || run.status == .cancelled
                }
                
                self.applyFiltersAndSort()
                self.isLoading = false
            }
        }
    }
    
    /// Get run details by ID
    func getRunDetail(id: UUID) -> SchoolRun? {
        return manager.getRun(id: id)
    }
    
    /// Search runs by title or stop names
    func searchRuns(query: String) {
        searchText = query
    }
    
    /// Clear all filters and search
    func clearFilters() {
        searchText = ""
        selectedDateRange = .all
        selectedStatusFilter = .all
        sortOption = .dateDescending
        resetPagination()
    }
    
    /// Load more runs for pagination
    func loadMoreRuns() {
        guard !isLoadingMore && hasMoreRuns else { return }
        
        isLoadingMore = true
        
        // Simulate async loading for better UX
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            await MainActor.run {
                let startIndex = currentPage * pageSize
                let endIndex = min(startIndex + pageSize, allFilteredRuns.count)
                
                if startIndex < allFilteredRuns.count {
                    let newRuns = Array(allFilteredRuns[startIndex..<endIndex])
                    paginatedFilteredRuns.append(contentsOf: newRuns)
                    currentPage += 1
                }
                
                isLoadingMore = false
            }
        }
    }
    
    /// Reset pagination to first page
    private func resetPagination() {
        currentPage = 0
        paginatedFilteredRuns.removeAll()
        loadFirstPage()
    }
    
    /// Load the first page of results
    private func loadFirstPage() {
        let endIndex = min(pageSize, allFilteredRuns.count)
        if endIndex > 0 {
            paginatedFilteredRuns = Array(allFilteredRuns[0..<endIndex])
            currentPage = 1
        }
    }
    
    /// Apply date range filter
    func applyDateRangeFilter(_ range: DateRange) {
        selectedDateRange = range
    }
    
    /// Apply status filter
    func applyStatusFilter(_ filter: StatusFilter) {
        selectedStatusFilter = filter
    }
    
    /// Apply sort option
    func applySortOption(_ option: SortOption) {
        sortOption = option
    }
    
    /// Set custom date range
    func setCustomDateRange(start: Date, end: Date) {
        customStartDate = start
        customEndDate = end
        selectedDateRange = .custom
    }
    
    /// Get runs for a specific date
    func getRuns(for date: Date) -> [SchoolRun] {
        return historicalRuns.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    /// Get runs within a specific date range
    func getRuns(from startDate: Date, to endDate: Date) -> [SchoolRun] {
        return historicalRuns.filter { $0.date >= startDate && $0.date <= endDate }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Refresh historical runs data
    func refresh() {
        loadHistoricalRuns()
    }
    
    // MARK: - Private Methods
    
    /// Setup bindings to observe manager changes
    private func setupBindings() {
        // Observe manager's runs changes and update historical runs
        manager.$runs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] runs in
                self?.historicalRuns = runs.filter { run in
                    run.status == .completed || run.status == .cancelled
                }
                self?.applyFiltersAndSort()
            }
            .store(in: &cancellables)
        
        // Observe manager's error messages
        manager.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
    }
    
    /// Apply current filters and sorting to the runs (optimized for performance)
    private func applyFiltersAndSort() {
        // Use background queue for heavy filtering operations
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            // Capture main actor properties on main thread first
            let historicalRuns = await MainActor.run { self.historicalRuns }
            let searchText = await MainActor.run { self.searchText }
            let selectedDateRange = await MainActor.run { self.selectedDateRange }
            let customStartDate = await MainActor.run { self.customStartDate }
            let customEndDate = await MainActor.run { self.customEndDate }
            let selectedStatusFilter = await MainActor.run { self.selectedStatusFilter }
            let sortOption = await MainActor.run { self.sortOption }
            
            var filtered = historicalRuns
            
            // Apply search filter (optimized)
            if !searchText.isEmpty {
                let searchTerms = searchText.lowercased().components(separatedBy: .whitespaces)
                filtered = filtered.filter { run in
                    let runText = "\(run.title) \(run.route.map { "\($0.name) \($0.note)" }.joined(separator: " "))".lowercased()
                    return searchTerms.allSatisfy { runText.contains($0) }
                }
            }
            
            // Apply date range filter
            let dateRange = selectedDateRange == .custom ? 
                (customStartDate, customEndDate) : 
                selectedDateRange.getDateRange()
            
            if let startDate = dateRange.start {
                filtered = filtered.filter { $0.date >= startDate }
            }
            
            if let endDate = dateRange.end {
                filtered = filtered.filter { $0.date <= endDate }
            }
            
            // Apply status filter
            if let status = selectedStatusFilter.runStatus {
                filtered = filtered.filter { $0.status == status }
            }
            
            // Apply sorting
            let sortedFiltered = await MainActor.run { self.sortRuns(filtered, by: sortOption) }
            
            // Update on main thread
            await MainActor.run {
                self.allFilteredRuns = sortedFiltered
                self.filteredRuns = sortedFiltered // Keep for compatibility
                self.resetPagination()
            }
        }
    }
    
    /// Sort runs based on the selected sort option
    private func sortRuns(_ runs: [SchoolRun], by option: SortOption) -> [SchoolRun] {
        switch option {
        case .dateDescending:
            return runs.sorted { $0.date > $1.date }
        case .dateAscending:
            return runs.sorted { $0.date < $1.date }
        case .titleAscending:
            return runs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleDescending:
            return runs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .durationAscending:
            return runs.sorted { $0.estimatedDuration < $1.estimatedDuration }
        case .durationDescending:
            return runs.sorted { $0.estimatedDuration > $1.estimatedDuration }
        }
    }
    
    // MARK: - Combine Support
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Supporting Types

/// Statistics for run history
struct RunStatistics {
    let totalRuns: Int
    let completedRuns: Int
    let cancelledRuns: Int
    let totalDuration: TimeInterval
    let averageDuration: TimeInterval
    
    /// Formatted total duration string
    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Formatted average duration string
    var formattedAverageDuration: String {
        let hours = Int(averageDuration) / 3600
        let minutes = (Int(averageDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Combine Import
import Combine