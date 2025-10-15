import Foundation
import SwiftData

/// Centralized service for all calendar caching operations
/// This service eliminates cache management duplication across services
@MainActor
class CalendarEventCacheService: ObservableObject {
    
    // MARK: - Cache Configuration
    
    private struct CacheConfig {
        static let maxCacheSize = 1000 // Maximum number of events to cache
        static let cacheExpiryInterval: TimeInterval = 300 // 5 minutes
        static let preloadDays = 30 // Days to preload around current date
        static let maxMemoryUsageMB = 50 // Maximum memory usage in MB
    }
    
    // MARK: - Cache Storage
    
    private var eventCache: [String: CachedEventCollection] = [:]
    private var lastAccessTimes: [String: Date] = [:]
    private var cacheMetrics = CacheMetrics()
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("🗄️ CalendarEventCacheService: Initialized with cache size limit: \(CacheConfig.maxCacheSize)")
        
        // Start cache maintenance timer
        startCacheMaintenanceTimer()
    }
    
    // MARK: - Public Cache Interface
    
    /// Loads events for a date range with intelligent caching
    func loadEvents(
        for dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        forceRefresh: Bool = false
    ) async throws -> [CalendarEvent] {
        
        let cacheKey = generateCacheKey(
            dateRange: dateRange,
            userId: userId,
            familyId: familyId,
            privacyLevel: privacyLevel
        )
        
        // Check cache first (unless force refresh)
        if !forceRefresh, let cachedCollection = getCachedEvents(for: cacheKey) {
            cacheMetrics.recordHit()
            print("✅ CalendarEventCacheService: Cache hit for key: \(cacheKey)")
            return cachedCollection.events
        }
        
        // Cache miss - load from database
        cacheMetrics.recordMiss()
        print("🔍 CalendarEventCacheService: Cache miss, loading from database for key: \(cacheKey)")
        
        let events = try await loadEventsFromDatabase(
            dateRange: dateRange,
            userId: userId,
            familyId: familyId,
            privacyLevel: privacyLevel
        )
        
        // Cache the results
        cacheEvents(events, for: cacheKey, dateRange: dateRange)
        
        return events
    }
    
    /// Preloads events around a specific date for better performance
    func preloadEventsAroundDate(_ date: Date, userId: UUID? = nil, familyId: UUID? = nil) async {
        let startDate = Calendar.current.date(byAdding: .day, value: -CacheConfig.preloadDays, to: date) ?? date
        let endDate = Calendar.current.date(byAdding: .day, value: CacheConfig.preloadDays, to: date) ?? date
        let dateRange = DateInterval(start: startDate, end: endDate)
        
        print("🔄 CalendarEventCacheService: Preloading events around \(date) (±\(CacheConfig.preloadDays) days)")
        
        do {
            _ = try await loadEvents(for: dateRange, userId: userId, familyId: familyId)
        } catch {
            print("⚠️ CalendarEventCacheService: Failed to preload events: \(error.localizedDescription)")
        }
    }
    
    /// Invalidates cache for specific criteria
    func invalidateCache(
        userId: UUID? = nil,
        familyId: UUID? = nil,
        eventId: UUID? = nil
    ) {
        let keysToRemove = eventCache.keys.filter { key in
            if let userId = userId, key.contains(userId.uuidString) {
                return true
            }
            if let familyId = familyId, key.contains(familyId.uuidString) {
                return true
            }
            if let eventId = eventId, 
               let cachedCollection = eventCache[key],
               cachedCollection.events.contains(where: { $0.id == eventId }) {
                return true
            }
            return false
        }
        
        for key in keysToRemove {
            eventCache.removeValue(forKey: key)
            lastAccessTimes.removeValue(forKey: key)
        }
        
        print("🗑️ CalendarEventCacheService: Invalidated \(keysToRemove.count) cache entries")
    }
    
    /// Clears all cached data
    func clearCache() {
        eventCache.removeAll()
        lastAccessTimes.removeAll()
        cacheMetrics.reset()
        print("🗑️ CalendarEventCacheService: Cleared all cache data")
    }
    
    /// Gets current cache statistics
    func getCacheMetrics() -> CacheMetrics {
        cacheMetrics.cacheSize = eventCache.count
        cacheMetrics.memoryUsageMB = estimateMemoryUsage()
        return cacheMetrics
    }
    
    // MARK: - Private Cache Implementation
    
    private func getCachedEvents(for key: String) -> CachedEventCollection? {
        guard let cachedCollection = eventCache[key] else {
            return nil
        }
        
        // Check if cache entry is still valid
        let now = Date()
        if now.timeIntervalSince(cachedCollection.timestamp) > CacheConfig.cacheExpiryInterval {
            eventCache.removeValue(forKey: key)
            lastAccessTimes.removeValue(forKey: key)
            return nil
        }
        
        // Update access time
        lastAccessTimes[key] = now
        
        return cachedCollection
    }
    
    private func cacheEvents(_ events: [CalendarEvent], for key: String, dateRange: DateInterval) {
        // Check cache size limits
        if eventCache.count >= CacheConfig.maxCacheSize {
            evictLeastRecentlyUsedEntries()
        }
        
        // Check memory usage
        if estimateMemoryUsage() > CacheConfig.maxMemoryUsageMB {
            evictLargestEntries()
        }
        
        let cachedCollection = CachedEventCollection(
            events: events,
            dateRange: dateRange,
            timestamp: Date()
        )
        
        eventCache[key] = cachedCollection
        lastAccessTimes[key] = Date()
        
        print("💾 CalendarEventCacheService: Cached \(events.count) events for key: \(key)")
    }
    
    private func loadEventsFromDatabase(
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil
    ) async throws -> [CalendarEvent] {
        
        // Build optimized predicate
        var predicates: [Predicate<CalendarEvent>] = []
        
        // Date range filter (most selective first)
        predicates.append(#Predicate<CalendarEvent> { event in
            event.startDate >= dateRange.start && event.startDate <= dateRange.end
        })
        
        // Not deleted filter
        predicates.append(#Predicate<CalendarEvent> { event in
            !event.isDeleted
        })
        
        // User filter
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
        
        // Combine predicates
        let combinedPredicate = predicates.reduce(nil) { result, predicate in
            if let result = result {
                return #Predicate<CalendarEvent> { event in
                    result.evaluate(event) && predicate.evaluate(event)
                }
            } else {
                return predicate
            }
        }
        
        // Create optimized fetch descriptor
        var descriptor = FetchDescriptor<CalendarEvent>()
        if let predicate = combinedPredicate {
            descriptor.predicate = predicate
        }
        
        // Sort by start date for better performance
        descriptor.sortBy = [SortDescriptor(\.startDate)]
        
        // Fetch events
        let events = try modelContext.fetch(descriptor)
        
        print("📊 CalendarEventCacheService: Loaded \(events.count) events from database")
        return events
    }
    
    private func generateCacheKey(
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil
    ) -> String {
        var components = [
            "range:\(Int(dateRange.start.timeIntervalSince1970))-\(Int(dateRange.end.timeIntervalSince1970))"
        ]
        
        if let userId = userId {
            components.append("user:\(userId.uuidString)")
        }
        
        if let familyId = familyId {
            components.append("family:\(familyId.uuidString)")
        }
        
        if let privacyLevel = privacyLevel {
            components.append("privacy:\(privacyLevel.rawValue)")
        }
        
        return components.joined(separator: "|")
    }
    
    private func evictLeastRecentlyUsedEntries() {
        let sortedByAccess = lastAccessTimes.sorted { $0.value < $1.value }
        let entriesToRemove = sortedByAccess.prefix(eventCache.count / 4) // Remove 25%
        
        for (key, _) in entriesToRemove {
            eventCache.removeValue(forKey: key)
            lastAccessTimes.removeValue(forKey: key)
        }
        
        print("🗑️ CalendarEventCacheService: Evicted \(entriesToRemove.count) LRU entries")
    }
    
    private func evictLargestEntries() {
        let sortedBySize = eventCache.sorted { $0.value.events.count > $1.value.events.count }
        let entriesToRemove = sortedBySize.prefix(eventCache.count / 4) // Remove 25%
        
        for (key, _) in entriesToRemove {
            eventCache.removeValue(forKey: key)
            lastAccessTimes.removeValue(forKey: key)
        }
        
        print("🗑️ CalendarEventCacheService: Evicted \(entriesToRemove.count) largest entries")
    }
    
    private func estimateMemoryUsage() -> Double {
        let totalEvents = eventCache.values.reduce(0) { $0 + $1.events.count }
        // Rough estimate: 1KB per event
        return Double(totalEvents) / 1024.0
    }
    
    private func startCacheMaintenanceTimer() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                self.performCacheMaintenance()
            }
        }
    }
    
    private func performCacheMaintenance() {
        let now = Date()
        let expiredKeys = eventCache.compactMap { key, collection in
            now.timeIntervalSince(collection.timestamp) > CacheConfig.cacheExpiryInterval ? key : nil
        }
        
        for key in expiredKeys {
            eventCache.removeValue(forKey: key)
            lastAccessTimes.removeValue(forKey: key)
        }
        
        if !expiredKeys.isEmpty {
            print("🧹 CalendarEventCacheService: Cleaned up \(expiredKeys.count) expired cache entries")
        }
    }
    
    // MARK: - Centralized Cache Coordination (eliminates duplication)
    
    /// Centralized cache optimization - called by background processor
    func optimizeStorage() async {
        print("🔧 CalendarEventCacheService: Optimizing cache storage")
        
        // Perform maintenance
        performCacheMaintenance()
        
        // Evict least recently used entries if over limit
        evictLeastRecentlyUsed()
        
        print("✅ CalendarEventCacheService: Cache optimization completed")
    }
    
    /// Gets comprehensive cache status for background processor
    func getCacheStatus() -> CacheStatus {
        let metrics = getCacheMetrics()
        
        return CacheStatus(
            totalEntries: eventCache.count,
            expiredEntries: countExpiredEntries(),
            cacheHitRate: metrics.hitRate,
            lastCleanup: Date() // Would track actual cleanup time in real implementation
        )
    }
    
    /// Clears expired cache entries
    func clearExpiredEntries() {
        performCacheMaintenance()
    }
    
    private func countExpiredEntries() -> Int {
        let now = Date()
        return eventCache.values.count { collection in
            now.timeIntervalSince(collection.timestamp) > CacheConfig.cacheExpiryInterval
        }
    }
    
    private func evictLeastRecentlyUsed() {
        guard eventCache.count > CacheConfig.maxCacheEntries else { return }
        
        // Find least recently used entries
        let sortedByAccess = lastAccessTimes.sorted { $0.value < $1.value }
        let entriesToRemove = sortedByAccess.prefix(eventCache.count - CacheConfig.maxCacheEntries)
        
        for (key, _) in entriesToRemove {
            eventCache.removeValue(forKey: key)
            lastAccessTimes.removeValue(forKey: key)
        }
        
        print("🗑️ CalendarEventCacheService: Evicted \(entriesToRemove.count) least recently used entries")
    }
}

// MARK: - Supporting Types

private struct CachedEventCollection {
    let events: [CalendarEvent]
    let dateRange: DateInterval
    let timestamp: Date
}

/// Cache performance metrics
struct CacheMetrics {
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0
    var cacheSize: Int = 0
    var memoryUsageMB: Double = 0
    
    var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0
    }
    
    mutating func recordHit() {
        hits += 1
    }
    
    mutating func recordMiss() {
        misses += 1
    }
    
    mutating func reset() {
        hits = 0
        misses = 0
        cacheSize = 0
        memoryUsageMB = 0
    }
    
    var description: String {
        return """
        Cache Metrics:
        - Hit Rate: \(String(format: "%.1f", hitRate * 100))%
        - Cache Size: \(cacheSize) entries
        - Memory Usage: \(String(format: "%.1f", memoryUsageMB)) MB
        - Total Requests: \(hits + misses)
        """
    }
}

// MARK: - Notification Extensions for Cache Coordination

extension Notification.Name {
    static let cacheInvalidated = Notification.Name("CalendarCacheInvalidated")
}