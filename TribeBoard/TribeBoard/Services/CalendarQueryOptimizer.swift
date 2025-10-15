import Foundation
import SwiftData

/// Service for optimizing Core Data queries for calendar operations
@MainActor
class CalendarQueryOptimizer: ObservableObject {
    
    // MARK: - Query Optimization Configuration
    
    private struct OptimizationConfig {
        static let batchSize = 100
        static let maxPredicateComplexity = 5
        static let indexHintThreshold = 1000 // Use index hints for large datasets
        static let queryTimeoutSeconds: TimeInterval = 30
    }
    
    // MARK: - Query Performance Metrics
    
    @Published var queryMetrics = QueryPerformanceMetrics()
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("⚡ CalendarQueryOptimizer: Initialized with optimization strategies")
    }
    
    // MARK: - Optimized Query Methods
    
    /// Executes an optimized event query with performance monitoring
    func executeOptimizedEventQuery(
        dateRange: DateInterval? = nil,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        searchText: String? = nil,
        sortBy: EventSortOption = .startDate,
        limit: Int? = nil,
        offset: Int = 0
    ) async throws -> OptimizedQueryResult<CalendarEvent> {
        
        let startTime = Date()
        let queryId = UUID().uuidString
        
        print("⚡ CalendarQueryOptimizer: Executing optimized query \(queryId)")
        
        do {
            // Build optimized predicate
            let predicate = buildOptimizedPredicate(
                dateRange: dateRange,
                userId: userId,
                familyId: familyId,
                privacyLevel: privacyLevel,
                searchText: searchText
            )
            
            // Create optimized fetch descriptor
            let descriptor = createOptimizedFetchDescriptor(
                predicate: predicate,
                sortBy: sortBy,
                limit: limit,
                offset: offset
            )
            
            // Execute query with timeout
            let events = try await executeWithTimeout(descriptor: descriptor)
            
            // Record performance metrics
            let executionTime = Date().timeIntervalSince(startTime)
            recordQueryMetrics(
                queryId: queryId,
                executionTime: executionTime,
                resultCount: events.count,
                predicateComplexity: calculatePredicateComplexity(
                    dateRange: dateRange,
                    userId: userId,
                    familyId: familyId,
                    privacyLevel: privacyLevel,
                    searchText: searchText
                )
            )
            
            return OptimizedQueryResult(
                events: events,
                executionTime: executionTime,
                queryId: queryId,
                optimizationsApplied: getAppliedOptimizations(descriptor: descriptor)
            )
            
        } catch {
            let executionTime = Date().timeIntervalSince(startTime)
            recordQueryError(queryId: queryId, error: error, executionTime: executionTime)
            throw error
        }
    }
    
    /// Executes a batch query for large datasets
    func executeBatchEventQuery(
        dateRange: DateInterval,
        batchSize: Int = OptimizationConfig.batchSize,
        processor: @escaping ([CalendarEvent]) async throws -> Void
    ) async throws {
        
        print("📦 CalendarQueryOptimizer: Executing batch query with batch size: \(batchSize)")
        
        var offset = 0
        var hasMoreData = true
        
        while hasMoreData {
            let result = try await executeOptimizedEventQuery(
                dateRange: dateRange,
                sortBy: .startDate,
                limit: batchSize,
                offset: offset
            )
            
            if result.events.isEmpty {
                hasMoreData = false
            } else {
                try await processor(result.events)
                offset += batchSize
                hasMoreData = result.events.count == batchSize
            }
        }
        
        print("✅ CalendarQueryOptimizer: Completed batch processing")
    }
    
    /// Gets event count with optimized counting query
    func getOptimizedEventCount(
        dateRange: DateInterval? = nil,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil
    ) async throws -> Int {
        
        let startTime = Date()
        
        // Build lightweight predicate for counting
        let predicate = buildOptimizedPredicate(
            dateRange: dateRange,
            userId: userId,
            familyId: familyId,
            privacyLevel: privacyLevel,
            searchText: nil
        )
        
        var descriptor = FetchDescriptor<CalendarEvent>()
        if let predicate = predicate {
            descriptor.predicate = predicate
        }
        
        // For counting, we don't need sorting or limits
        let events = try modelContext.fetch(descriptor)
        let count = events.count
        
        let executionTime = Date().timeIntervalSince(startTime)
        print("📊 CalendarQueryOptimizer: Count query executed in \(String(format: "%.3f", executionTime))s, result: \(count)")
        
        return count
    }
    
    /// Executes an aggregated query for calendar statistics
    func executeAggregatedQuery(
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil
    ) async throws -> CalendarAggregateStats {
        
        print("📈 CalendarQueryOptimizer: Executing aggregated statistics query")
        
        let result = try await executeOptimizedEventQuery(
            dateRange: dateRange,
            userId: userId,
            familyId: familyId
        )
        
        let events = result.events
        let now = Date()
        
        let stats = CalendarAggregateStats(
            totalEvents: events.count,
            familyEvents: events.filter { $0.privacyLevel == .familyShared }.count,
            personalEvents: events.filter { $0.privacyLevel == .personal }.count,
            upcomingEvents: events.filter { $0.startDate > now }.count,
            pastEvents: events.filter { $0.endDate < now }.count,
            todayEvents: events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: now) }.count,
            allDayEvents: events.filter { $0.isAllDay }.count,
            eventsWithLocation: events.filter { $0.location != nil && !$0.location!.isEmpty }.count,
            uniqueCreators: Set(events.map { $0.createdBy }).count,
            dateRange: dateRange,
            queryExecutionTime: result.executionTime
        )
        
        return stats
    }
    
    /// Finds events with potential conflicts efficiently
    func findConflictingEvents(
        for event: CalendarEvent,
        userId: UUID? = nil
    ) async throws -> [CalendarEvent] {
        
        print("🔍 CalendarQueryOptimizer: Finding conflicting events for event: \(event.id)")
        
        // Create a tight date range around the event
        let bufferMinutes: TimeInterval = 15 * 60 // 15 minutes buffer
        let startRange = event.startDate.addingTimeInterval(-bufferMinutes)
        let endRange = event.endDate.addingTimeInterval(bufferMinutes)
        let dateRange = DateInterval(start: startRange, end: endRange)
        
        let result = try await executeOptimizedEventQuery(
            dateRange: dateRange,
            userId: userId ?? event.createdBy
        )
        
        // Filter for actual conflicts
        let conflicts = result.events.filter { otherEvent in
            otherEvent.id != event.id &&
            !otherEvent.isDeleted &&
            eventsOverlap(event, otherEvent)
        }
        
        print("⚠️ CalendarQueryOptimizer: Found \(conflicts.count) conflicting events")
        return conflicts
    }
    
    /// Searches events with optimized text search
    func searchEvents(
        searchText: String,
        dateRange: DateInterval? = nil,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        limit: Int = 50
    ) async throws -> [CalendarEvent] {
        
        print("🔍 CalendarQueryOptimizer: Searching events with text: '\(searchText)'")
        
        let result = try await executeOptimizedEventQuery(
            dateRange: dateRange,
            userId: userId,
            familyId: familyId,
            searchText: searchText,
            sortBy: .lastModified,
            limit: limit
        )
        
        return result.events
    }
    
    // MARK: - Private Optimization Implementation
    
    private func buildOptimizedPredicate(
        dateRange: DateInterval? = nil,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        searchText: String? = nil
    ) -> Predicate<CalendarEvent>? {
        
        var predicates: [Predicate<CalendarEvent>] = []
        
        // Always filter out deleted events first (most selective)
        predicates.append(#Predicate<CalendarEvent> { event in
            !event.isDeleted
        })
        
        // Date range filter (usually very selective)
        if let dateRange = dateRange {
            predicates.append(#Predicate<CalendarEvent> { event in
                event.startDate >= dateRange.start && event.startDate <= dateRange.end
            })
        }
        
        // User filter (selective for personal queries)
        if let userId = userId {
            predicates.append(#Predicate<CalendarEvent> { event in
                event.createdBy == userId
            })
        }
        
        // Family filter
        if let familyId = familyId {
            predicates.append(#Predicate<CalendarEvent> { event in
                event.familyId == familyId
            })
        }
        
        // Privacy level filter
        if let privacyLevel = privacyLevel {
            predicates.append(#Predicate<CalendarEvent> { event in
                event.privacyLevel == privacyLevel
            })
        }
        
        // Text search (least selective, add last)
        if let searchText = searchText, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lowercaseSearch = searchText.lowercased()
            predicates.append(#Predicate<CalendarEvent> { event in
                event.title.lowercased().contains(lowercaseSearch) ||
                (event.notes?.lowercased().contains(lowercaseSearch) ?? false) ||
                (event.location?.lowercased().contains(lowercaseSearch) ?? false)
            })
        }
        
        // Combine predicates efficiently
        return predicates.reduce(nil) { result, predicate in
            if let result = result {
                return #Predicate<CalendarEvent> { event in
                    result.evaluate(event) && predicate.evaluate(event)
                }
            } else {
                return predicate
            }
        }
    }
    
    private func createOptimizedFetchDescriptor(
        predicate: Predicate<CalendarEvent>?,
        sortBy: EventSortOption,
        limit: Int?,
        offset: Int
    ) -> FetchDescriptor<CalendarEvent> {
        
        var descriptor = FetchDescriptor<CalendarEvent>()
        
        // Set predicate
        if let predicate = predicate {
            descriptor.predicate = predicate
        }
        
        // Set optimized sort descriptors
        descriptor.sortBy = getOptimizedSortDescriptors(for: sortBy)
        
        // Set pagination
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        
        if offset > 0 {
            descriptor.fetchOffset = offset
        }
        
        return descriptor
    }
    
    private func getOptimizedSortDescriptors(for sortOption: EventSortOption) -> [SortDescriptor<CalendarEvent>] {
        // Use indexed fields for better performance
        switch sortOption {
        case .startDate:
            return [SortDescriptor(\.startDate), SortDescriptor(\.id)] // Add secondary sort for consistency
        case .startDateDescending:
            return [SortDescriptor(\.startDate, order: .reverse), SortDescriptor(\.id)]
        case .title:
            return [SortDescriptor(\.title), SortDescriptor(\.startDate)]
        case .lastModified:
            return [SortDescriptor(\.lastModified, order: .reverse), SortDescriptor(\.id)]
        case .createdDate:
            return [SortDescriptor(\.createdAt, order: .reverse), SortDescriptor(\.id)]
        }
    }
    
    private func executeWithTimeout(descriptor: FetchDescriptor<CalendarEvent>) async throws -> [CalendarEvent] {
        return try await withThrowingTaskGroup(of: [CalendarEvent].self) { group in
            // Add the main query task
            group.addTask {
                return try self.modelContext.fetch(descriptor)
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(OptimizationConfig.queryTimeoutSeconds * 1_000_000_000))
                throw CalendarQueryError.queryTimeout
            }
            
            // Return the first completed task (either result or timeout)
            guard let result = try await group.next() else {
                throw CalendarQueryError.queryFailed("No result returned")
            }
            
            // Cancel remaining tasks
            group.cancelAll()
            
            return result
        }
    }
    
    private func calculatePredicateComplexity(
        dateRange: DateInterval?,
        userId: UUID?,
        familyId: UUID?,
        privacyLevel: CalendarEvent.PrivacyLevel?,
        searchText: String?
    ) -> Int {
        var complexity = 1 // Base complexity for isDeleted filter
        
        if dateRange != nil { complexity += 1 }
        if userId != nil { complexity += 1 }
        if familyId != nil { complexity += 1 }
        if privacyLevel != nil { complexity += 1 }
        if searchText != nil && !searchText!.isEmpty { complexity += 2 } // Text search is more expensive
        
        return complexity
    }
    
    private func getAppliedOptimizations(descriptor: FetchDescriptor<CalendarEvent>) -> [String] {
        var optimizations: [String] = []
        
        if descriptor.predicate != nil {
            optimizations.append("Predicate Optimization")
        }
        
        if !descriptor.sortBy.isEmpty {
            optimizations.append("Sort Optimization")
        }
        
        if descriptor.fetchLimit != nil {
            optimizations.append("Limit Optimization")
        }
        
        if descriptor.fetchOffset > 0 {
            optimizations.append("Offset Pagination")
        }
        
        return optimizations
    }
    
    private func eventsOverlap(_ event1: CalendarEvent, _ event2: CalendarEvent) -> Bool {
        return event1.startDate < event2.endDate && event2.startDate < event1.endDate
    }
    
    private func recordQueryMetrics(
        queryId: String,
        executionTime: TimeInterval,
        resultCount: Int,
        predicateComplexity: Int
    ) {
        queryMetrics.recordQuery(
            executionTime: executionTime,
            resultCount: resultCount,
            predicateComplexity: predicateComplexity
        )
        
        print("📊 CalendarQueryOptimizer: Query \(queryId) completed in \(String(format: "%.3f", executionTime))s, \(resultCount) results")
    }
    
    private func recordQueryError(queryId: String, error: Error, executionTime: TimeInterval) {
        queryMetrics.recordError()
        print("❌ CalendarQueryOptimizer: Query \(queryId) failed after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)")
    }
}

// MARK: - Supporting Types

/// Result of an optimized query with performance data
struct OptimizedQueryResult<T> {
    let events: [T]
    let executionTime: TimeInterval
    let queryId: String
    let optimizationsApplied: [String]
}

/// Calendar aggregate statistics
struct CalendarAggregateStats {
    let totalEvents: Int
    let familyEvents: Int
    let personalEvents: Int
    let upcomingEvents: Int
    let pastEvents: Int
    let todayEvents: Int
    let allDayEvents: Int
    let eventsWithLocation: Int
    let uniqueCreators: Int
    let dateRange: DateInterval
    let queryExecutionTime: TimeInterval
    
    var description: String {
        return """
        Calendar Statistics (\(dateRange.start) - \(dateRange.end)):
        - Total Events: \(totalEvents)
        - Family Events: \(familyEvents)
        - Personal Events: \(personalEvents)
        - Upcoming: \(upcomingEvents)
        - Past: \(pastEvents)
        - Today: \(todayEvents)
        - All Day: \(allDayEvents)
        - With Location: \(eventsWithLocation)
        - Unique Creators: \(uniqueCreators)
        - Query Time: \(String(format: "%.3f", queryExecutionTime))s
        """
    }
}

/// Query performance metrics tracking
struct QueryPerformanceMetrics {
    private(set) var totalQueries: Int = 0
    private(set) var totalExecutionTime: TimeInterval = 0
    private(set) var totalResults: Int = 0
    private(set) var errorCount: Int = 0
    private(set) var slowQueryCount: Int = 0
    
    private let slowQueryThreshold: TimeInterval = 1.0 // 1 second
    
    var averageExecutionTime: TimeInterval {
        guard totalQueries > 0 else { return 0 }
        return totalExecutionTime / Double(totalQueries)
    }
    
    var averageResultCount: Double {
        guard totalQueries > 0 else { return 0 }
        return Double(totalResults) / Double(totalQueries)
    }
    
    var errorRate: Double {
        guard totalQueries > 0 else { return 0 }
        return Double(errorCount) / Double(totalQueries)
    }
    
    var slowQueryRate: Double {
        guard totalQueries > 0 else { return 0 }
        return Double(slowQueryCount) / Double(totalQueries)
    }
    
    mutating func recordQuery(executionTime: TimeInterval, resultCount: Int, predicateComplexity: Int) {
        totalQueries += 1
        totalExecutionTime += executionTime
        totalResults += resultCount
        
        if executionTime > slowQueryThreshold {
            slowQueryCount += 1
        }
    }
    
    mutating func recordError() {
        errorCount += 1
    }
    
    mutating func reset() {
        totalQueries = 0
        totalExecutionTime = 0
        totalResults = 0
        errorCount = 0
        slowQueryCount = 0
    }
    
    var description: String {
        return """
        Query Performance Metrics:
        - Total Queries: \(totalQueries)
        - Average Execution Time: \(String(format: "%.3f", averageExecutionTime))s
        - Average Results: \(String(format: "%.1f", averageResultCount))
        - Error Rate: \(String(format: "%.1f", errorRate * 100))%
        - Slow Query Rate: \(String(format: "%.1f", slowQueryRate * 100))%
        """
    }
}

/// Calendar query specific errors
enum CalendarQueryError: LocalizedError {
    case queryTimeout
    case queryFailed(String)
    case predicateTooComplex
    
    var errorDescription: String? {
        switch self {
        case .queryTimeout:
            return "Query timed out"
        case .queryFailed(let reason):
            return "Query failed: \(reason)"
        case .predicateTooComplex:
            return "Query predicate is too complex"
        }
    }
}