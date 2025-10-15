import Foundation
import SwiftData

/// Enhanced calendar service with performance optimizations for large datasets
@MainActor
class CalendarPerformanceService: ObservableObject {
    
    // MARK: - Performance Configuration
    
    private struct PerformanceConfig {
        static let cachePreloadDays = 30
        static let defaultPageSize = 50
        static let maxConcurrentOperations = 5
        static let performanceMonitoringEnabled = true
        static let autoOptimizationEnabled = true
    }
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var loadingProgress: Double = 0
    @Published var performanceMetrics = ServicePerformanceMetrics()
    @Published var error: Error?
    
    // MARK: - Performance Components
    
    private let cacheService: CalendarEventCacheService
    private let paginationManager: CalendarPaginationManager
    private let queryOptimizer: CalendarQueryOptimizer
    private let backgroundProcessor: CalendarBackgroundSyncProcessor
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private let calendarService: CalendarService
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        calendarService: CalendarService,
        calendarSyncService: CalendarSyncService,
        networkMonitor: NetworkMonitor
    ) {
        self.modelContext = modelContext
        self.calendarService = calendarService
        
        // Initialize performance components
        self.cacheService = CalendarEventCacheService(modelContext: modelContext)
        self.paginationManager = CalendarPaginationManager(
            modelContext: modelContext,
            cacheService: cacheService
        )
        self.queryOptimizer = CalendarQueryOptimizer(modelContext: modelContext)
        self.backgroundProcessor = CalendarBackgroundSyncProcessor(
            modelContext: modelContext,
            calendarSyncService: calendarSyncService,
            networkMonitor: networkMonitor,
            cacheService: cacheService
        )
        
        print("⚡ CalendarPerformanceService: Initialized with performance optimizations")
        
        // Start performance monitoring
        if PerformanceConfig.performanceMonitoringEnabled {
            startPerformanceMonitoring()
        }
    }
    
    // MARK: - Optimized Event Loading
    
    /// Loads events with intelligent caching and pagination
    func loadEventsOptimized(
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        pageSize: Int = PerformanceConfig.defaultPageSize,
        forceRefresh: Bool = false
    ) async throws -> OptimizedEventResult {
        
        let startTime = Date()
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
            loadingProgress = 0
        }
        
        do {
            // Try cache first (unless force refresh)
            if !forceRefresh {
                let cachedEvents = try await cacheService.loadEvents(
                    for: dateRange,
                    userId: userId,
                    familyId: familyId,
                    privacyLevel: privacyLevel
                )
                
                if !cachedEvents.isEmpty {
                    let executionTime = Date().timeIntervalSince(startTime)
                    recordPerformanceMetric(operation: "loadEventsOptimized", executionTime: executionTime, resultCount: cachedEvents.count, cacheHit: true)
                    
                    return OptimizedEventResult(
                        events: cachedEvents,
                        totalCount: cachedEvents.count,
                        isFromCache: true,
                        executionTime: executionTime,
                        optimizationsApplied: ["Cache Hit"]
                    )
                }
            }
            
            // Cache miss - use optimized query with pagination
            loadingProgress = 0.3
            
            let queryResult = try await queryOptimizer.executeOptimizedEventQuery(
                dateRange: dateRange,
                userId: userId,
                familyId: familyId,
                privacyLevel: privacyLevel,
                limit: pageSize
            )
            
            loadingProgress = 0.7
            
            // Get total count for pagination
            let totalCount = try await queryOptimizer.getOptimizedEventCount(
                dateRange: dateRange,
                userId: userId,
                familyId: familyId,
                privacyLevel: privacyLevel
            )
            
            loadingProgress = 1.0
            
            let executionTime = Date().timeIntervalSince(startTime)
            recordPerformanceMetric(operation: "loadEventsOptimized", executionTime: executionTime, resultCount: queryResult.events.count, cacheHit: false)
            
            // Preload surrounding dates for better UX
            Task {
                await preloadSurroundingEvents(
                    around: dateRange,
                    userId: userId,
                    familyId: familyId
                )
            }
            
            return OptimizedEventResult(
                events: queryResult.events,
                totalCount: totalCount,
                isFromCache: false,
                executionTime: executionTime,
                optimizationsApplied: queryResult.optimizationsApplied
            )
            
        } catch {
            self.error = error
            let executionTime = Date().timeIntervalSince(startTime)
            recordPerformanceError(operation: "loadEventsOptimized", error: error, executionTime: executionTime)
            throw error
        }
    }
    
    /// Loads events with pagination support
    func loadEventsPaginated(
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        sortBy: EventSortOption = .startDate,
        pageSize: Int = PerformanceConfig.defaultPageSize
    ) async throws -> PaginatedEventResult {
        
        let startTime = Date()
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            // Load first page
            let events = try await paginationManager.loadFirstPage(
                dateRange: dateRange,
                userId: userId,
                familyId: familyId,
                privacyLevel: privacyLevel,
                sortBy: sortBy
            )
            
            let stats = paginationManager.getPaginationStats()
            let executionTime = Date().timeIntervalSince(startTime)
            
            recordPerformanceMetric(operation: "loadEventsPaginated", executionTime: executionTime, resultCount: events.count, cacheHit: false)
            
            return PaginatedEventResult(
                events: events,
                paginationStats: stats,
                executionTime: executionTime,
                hasMorePages: paginationManager.hasMorePages
            )
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Loads next page of events
    func loadNextPage(
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        sortBy: EventSortOption = .startDate
    ) async throws -> [CalendarEvent] {
        
        return try await paginationManager.loadNextPage(
            dateRange: dateRange,
            userId: userId,
            familyId: familyId,
            privacyLevel: privacyLevel,
            sortBy: sortBy
        )
    }
    
    /// Searches events with optimized text search
    func searchEventsOptimized(
        searchText: String,
        dateRange: DateInterval? = nil,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        limit: Int = 50
    ) async throws -> [CalendarEvent] {
        
        let startTime = Date()
        
        do {
            let events = try await queryOptimizer.searchEvents(
                searchText: searchText,
                dateRange: dateRange,
                userId: userId,
                familyId: familyId,
                limit: limit
            )
            
            let executionTime = Date().timeIntervalSince(startTime)
            recordPerformanceMetric(operation: "searchEventsOptimized", executionTime: executionTime, resultCount: events.count, cacheHit: false)
            
            return events
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Gets calendar statistics with optimized aggregation
    func getCalendarStatistics(
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil
    ) async throws -> CalendarAggregateStats {
        
        return try await queryOptimizer.executeAggregatedQuery(
            dateRange: dateRange,
            userId: userId,
            familyId: familyId
        )
    }
    
    /// Finds conflicting events efficiently
    func findConflictingEvents(
        for event: CalendarEvent,
        userId: UUID? = nil
    ) async throws -> [CalendarEvent] {
        
        return try await queryOptimizer.findConflictingEvents(
            for: event,
            userId: userId
        )
    }
    
    // MARK: - Background Processing
    
    /// Processes pending sync operations in background - coordinates with CalendarBackgroundSyncProcessor
    func processBackgroundSync() async {
        print("🔄 CalendarPerformanceService: Coordinating background sync with CalendarBackgroundSyncProcessor")
        
        // Use the centralized background processor for all background operations
        await backgroundProcessor.processAllBackgroundOperations()
    }
    
    /// Schedules background sync - delegates to CalendarBackgroundSyncProcessor
    func scheduleBackgroundSync() {
        print("⏰ CalendarPerformanceService: Delegating background sync scheduling")
        
        backgroundProcessor.scheduleBackgroundSync()
    }
    
    /// Forces background sync for a user - coordinates with CalendarBackgroundSyncProcessor
    func forceBackgroundSync(for userId: UUID) async {
        print("🔄 CalendarPerformanceService: Coordinating forced background sync")
        
        // Use the coordinated background sync method
        await backgroundProcessor.coordinateBackgroundSyncWithCalendarService(for: userId)
    }
    
    /// Gets comprehensive background sync status
    func getBackgroundSyncStatus() -> BackgroundSyncStatus {
        return backgroundProcessor.getBackgroundSyncStatus()
    }
    
    /// Gets comprehensive background processing status
    func getComprehensiveBackgroundStatus() -> ComprehensiveBackgroundStatus {
        return backgroundProcessor.getComprehensiveBackgroundStatus()
    }
    
    // MARK: - Cache Management
    
    /// Preloads events around a date for better performance
    func preloadEvents(around date: Date, userId: UUID? = nil, familyId: UUID? = nil) async {
        await cacheService.preloadEventsAroundDate(date, userId: userId, familyId: familyId)
    }
    
    /// Invalidates cache for specific criteria - uses centralized coordination
    func invalidateCache(userId: UUID? = nil, familyId: UUID? = nil, eventId: UUID? = nil) {
        // Use centralized cache coordination to eliminate duplication
        cacheService.coordinateInvalidation(userId: userId, familyId: familyId, eventId: eventId)
    }
    
    /// Clears all cached data
    func clearCache() {
        cacheService.clearCache()
        paginationManager.reset()
    }
    
    /// Gets cache performance metrics
    func getCacheMetrics() -> CacheMetrics {
        return cacheService.getCacheMetrics()
    }
    
    // MARK: - Performance Monitoring
    
    /// Gets comprehensive performance metrics
    func getPerformanceMetrics() -> ComprehensivePerformanceMetrics {
        return ComprehensivePerformanceMetrics(
            serviceMetrics: performanceMetrics,
            cacheMetrics: cacheService.getCacheMetrics(),
            queryMetrics: queryOptimizer.queryMetrics,
            paginationStats: paginationManager.getPaginationStats(),
            backgroundSyncStats: backgroundProcessor.backgroundSyncStats
        )
    }
    
    /// Optimizes performance based on usage patterns
    func optimizePerformance() async {
        guard PerformanceConfig.autoOptimizationEnabled else { return }
        
        print("🔧 CalendarPerformanceService: Running performance optimization")
        
        let metrics = getPerformanceMetrics()
        
        // Optimize cache based on hit rate
        if metrics.cacheMetrics.hitRate < 0.7 {
            print("📈 CalendarPerformanceService: Low cache hit rate, clearing and rebuilding cache")
            clearCache()
        }
        
        // Optimize queries if they're running slow
        if metrics.queryMetrics.averageExecutionTime > 1.0 {
            print("🐌 CalendarPerformanceService: Slow queries detected, optimizing")
            // In a real implementation, you might adjust query strategies here
        }
        
        // Process comprehensive background operations if there are many pending operations
        if metrics.backgroundSyncStats.totalOperationsProcessed > 100 {
            print("🔄 CalendarPerformanceService: Many pending operations, processing comprehensive background operations")
            await processBackgroundSync()
        }
    }
    
    // MARK: - Batch Operations
    
    /// Processes events in batches for large datasets
    func processBatchOperation(
        dateRange: DateInterval,
        batchSize: Int = 100,
        processor: @escaping ([CalendarEvent]) async throws -> Void
    ) async throws {
        
        try await queryOptimizer.executeBatchEventQuery(
            dateRange: dateRange,
            batchSize: batchSize,
            processor: processor
        )
    }
    
    // MARK: - Private Implementation
    
    private func preloadSurroundingEvents(
        around dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil
    ) async {
        
        let calendar = Calendar.current
        let centerDate = dateRange.start.addingTimeInterval(dateRange.duration / 2)
        
        // Preload events for the month containing the center date
        guard let monthStart = calendar.dateInterval(of: .month, for: centerDate)?.start,
              let monthEnd = calendar.dateInterval(of: .month, for: centerDate)?.end else {
            return
        }
        
        let extendedRange = DateInterval(start: monthStart, end: monthEnd)
        
        do {
            _ = try await cacheService.loadEvents(
                for: extendedRange,
                userId: userId,
                familyId: familyId
            )
            print("✅ CalendarPerformanceService: Preloaded events for month around \(centerDate)")
        } catch {
            print("⚠️ CalendarPerformanceService: Failed to preload surrounding events: \(error.localizedDescription)")
        }
    }
    
    private func startPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                await self.performPerformanceCheck()
            }
        }
    }
    
    private func performPerformanceCheck() async {
        let metrics = getPerformanceMetrics()
        
        // Log performance summary
        if metrics.serviceMetrics.totalOperations > 0 {
            print("📊 CalendarPerformanceService Performance Summary:")
            print("   - Average Operation Time: \(String(format: "%.3f", metrics.serviceMetrics.averageExecutionTime))s")
            print("   - Cache Hit Rate: \(String(format: "%.1f", metrics.cacheMetrics.hitRate * 100))%")
            print("   - Query Performance: \(String(format: "%.3f", metrics.queryMetrics.averageExecutionTime))s avg")
            print("   - Error Rate: \(String(format: "%.1f", metrics.serviceMetrics.errorRate * 100))%")
        }
        
        // Auto-optimize if needed
        if PerformanceConfig.autoOptimizationEnabled {
            await optimizePerformance()
        }
    }
    
    private func recordPerformanceMetric(
        operation: String,
        executionTime: TimeInterval,
        resultCount: Int,
        cacheHit: Bool
    ) {
        performanceMetrics.recordOperation(
            operation: operation,
            executionTime: executionTime,
            resultCount: resultCount,
            cacheHit: cacheHit
        )
    }
    
    private func recordPerformanceError(
        operation: String,
        error: Error,
        executionTime: TimeInterval
    ) {
        performanceMetrics.recordError(
            operation: operation,
            error: error,
            executionTime: executionTime
        )
    }
}

// MARK: - Supporting Types

/// Result of optimized event loading
struct OptimizedEventResult {
    let events: [CalendarEvent]
    let totalCount: Int
    let isFromCache: Bool
    let executionTime: TimeInterval
    let optimizationsApplied: [String]
}

/// Result of paginated event loading
struct PaginatedEventResult {
    let events: [CalendarEvent]
    let paginationStats: PaginationStats
    let executionTime: TimeInterval
    let hasMorePages: Bool
}

/// Service performance metrics
struct ServicePerformanceMetrics {
    private(set) var totalOperations: Int = 0
    private(set) var totalExecutionTime: TimeInterval = 0
    private(set) var totalResults: Int = 0
    private(set) var cacheHits: Int = 0
    private(set) var errorCount: Int = 0
    private(set) var operationBreakdown: [String: Int] = [:]
    
    var averageExecutionTime: TimeInterval {
        guard totalOperations > 0 else { return 0 }
        return totalExecutionTime / Double(totalOperations)
    }
    
    var averageResultCount: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(totalResults) / Double(totalOperations)
    }
    
    var cacheHitRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(cacheHits) / Double(totalOperations)
    }
    
    var errorRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(errorCount) / Double(totalOperations)
    }
    
    mutating func recordOperation(
        operation: String,
        executionTime: TimeInterval,
        resultCount: Int,
        cacheHit: Bool
    ) {
        totalOperations += 1
        totalExecutionTime += executionTime
        totalResults += resultCount
        
        if cacheHit {
            cacheHits += 1
        }
        
        operationBreakdown[operation, default: 0] += 1
    }
    
    mutating func recordError(operation: String, error: Error, executionTime: TimeInterval) {
        errorCount += 1
        totalExecutionTime += executionTime
        operationBreakdown[operation, default: 0] += 1
    }
    
    mutating func reset() {
        totalOperations = 0
        totalExecutionTime = 0
        totalResults = 0
        cacheHits = 0
        errorCount = 0
        operationBreakdown.removeAll()
    }
}

/// Comprehensive performance metrics combining all components
struct ComprehensivePerformanceMetrics {
    let serviceMetrics: ServicePerformanceMetrics
    let cacheMetrics: CacheMetrics
    let queryMetrics: QueryPerformanceMetrics
    let paginationStats: PaginationStats
    let backgroundSyncStats: BackgroundSyncStats
    
    var overallHealthScore: Double {
        var score = 1.0
        
        // Penalize for high error rates
        score *= (1.0 - serviceMetrics.errorRate)
        
        // Reward good cache performance
        score *= (0.5 + 0.5 * cacheMetrics.hitRate)
        
        // Penalize for slow queries
        if queryMetrics.averageExecutionTime > 1.0 {
            score *= 0.8
        }
        
        // Reward successful background syncs
        score *= (0.7 + 0.3 * backgroundSyncStats.successRate)
        
        return max(0.0, min(1.0, score))
    }
    
    var performanceGrade: String {
        let score = overallHealthScore
        
        if score >= 0.9 {
            return "A"
        } else if score >= 0.8 {
            return "B"
        } else if score >= 0.7 {
            return "C"
        } else if score >= 0.6 {
            return "D"
        } else {
            return "F"
        }
    }
    
    var description: String {
        return """
        Calendar Performance Report (Grade: \(performanceGrade)):
        
        Service Metrics:
        - Operations: \(serviceMetrics.totalOperations)
        - Avg Execution: \(String(format: "%.3f", serviceMetrics.averageExecutionTime))s
        - Cache Hit Rate: \(String(format: "%.1f", serviceMetrics.cacheHitRate * 100))%
        - Error Rate: \(String(format: "%.1f", serviceMetrics.errorRate * 100))%
        
        Cache Performance:
        - Hit Rate: \(String(format: "%.1f", cacheMetrics.hitRate * 100))%
        - Cache Size: \(cacheMetrics.cacheSize) entries
        - Memory Usage: \(String(format: "%.1f", cacheMetrics.memoryUsageMB)) MB
        
        Query Performance:
        - Avg Query Time: \(String(format: "%.3f", queryMetrics.averageExecutionTime))s
        - Slow Query Rate: \(String(format: "%.1f", queryMetrics.slowQueryRate * 100))%
        
        Background Sync:
        - Success Rate: \(String(format: "%.1f", backgroundSyncStats.successRate * 100))%
        - Operations Processed: \(backgroundSyncStats.totalOperationsProcessed)
        
        Overall Health Score: \(String(format: "%.1f", overallHealthScore * 100))%
        """
    }
}