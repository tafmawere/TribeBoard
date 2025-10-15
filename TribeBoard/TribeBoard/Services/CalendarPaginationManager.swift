import Foundation
import SwiftData

/// Manager for paginating large event collections efficiently
@MainActor
class CalendarPaginationManager: ObservableObject {
    
    // MARK: - Pagination Configuration
    
    struct PaginationConfig {
        static let defaultPageSize = 50
        static let maxPageSize = 200
        static let preloadThreshold = 10 // Load next page when this many items from end
        static let maxCachedPages = 5
    }
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var hasMorePages = true
    @Published var currentPage = 0
    @Published var totalItems = 0
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    private var pageSize: Int
    private var cachedPages: [Int: PaginatedEventPage] = [:]
    private var loadingPages: Set<Int> = []
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private let cacheService: CalendarEventCacheService
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        cacheService: CalendarEventCacheService,
        pageSize: Int = PaginationConfig.defaultPageSize
    ) {
        self.modelContext = modelContext
        self.cacheService = cacheService
        self.pageSize = min(pageSize, PaginationConfig.maxPageSize)
        
        print("📄 CalendarPaginationManager: Initialized with page size: \(self.pageSize)")
    }
    
    // MARK: - Public Pagination Interface
    
    /// Loads the first page of events for given criteria
    func loadFirstPage(
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        sortBy: EventSortOption = .startDate
    ) async throws -> [CalendarEvent] {
        
        print("📄 CalendarPaginationManager: Loading first page")
        
        // Reset pagination state
        currentPage = 0
        cachedPages.removeAll()
        loadingPages.removeAll()
        hasMorePages = true
        error = nil
        
        // Load total count first
        totalItems = try await getTotalEventCount(
            dateRange: dateRange,
            userId: userId,
            familyId: familyId,
            privacyLevel: privacyLevel
        )
        
        // Load first page
        return try await loadPage(
            page: 0,
            dateRange: dateRange,
            userId: userId,
            familyId: familyId,
            privacyLevel: privacyLevel,
            sortBy: sortBy
        )
    }
    
    /// Loads a specific page of events
    func loadPage(
        page: Int,
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        sortBy: EventSortOption = .startDate
    ) async throws -> [CalendarEvent] {
        
        // Check if page is already cached
        if let cachedPage = cachedPages[page] {
            print("✅ CalendarPaginationManager: Page \(page) found in cache")
            return cachedPage.events
        }
        
        // Check if page is already loading
        if loadingPages.contains(page) {
            print("⏳ CalendarPaginationManager: Page \(page) is already loading")
            // Wait for loading to complete (simplified approach)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            return cachedPages[page]?.events ?? []
        }
        
        loadingPages.insert(page)
        isLoading = true
        error = nil
        
        defer {
            loadingPages.remove(page)
            isLoading = loadingPages.isEmpty ? false : isLoading
        }
        
        do {
            let events = try await loadEventsForPage(
                page: page,
                dateRange: dateRange,
                userId: userId,
                familyId: familyId,
                privacyLevel: privacyLevel,
                sortBy: sortBy
            )
            
            // Cache the page
            let paginatedPage = PaginatedEventPage(
                pageNumber: page,
                events: events,
                timestamp: Date()
            )
            
            cachedPages[page] = paginatedPage
            currentPage = max(currentPage, page)
            
            // Update hasMorePages
            hasMorePages = events.count == pageSize
            
            // Manage cache size
            manageCacheSize()
            
            print("✅ CalendarPaginationManager: Loaded page \(page) with \(events.count) events")
            return events
            
        } catch {
            self.error = error
            print("❌ CalendarPaginationManager: Failed to load page \(page): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Loads the next page of events
    func loadNextPage(
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        sortBy: EventSortOption = .startDate
    ) async throws -> [CalendarEvent] {
        
        guard hasMorePages else {
            print("ℹ️ CalendarPaginationManager: No more pages to load")
            return []
        }
        
        let nextPage = currentPage + 1
        return try await loadPage(
            page: nextPage,
            dateRange: dateRange,
            userId: userId,
            familyId: familyId,
            privacyLevel: privacyLevel,
            sortBy: sortBy
        )
    }
    
    /// Gets all currently loaded events across all pages
    func getAllLoadedEvents(sortBy: EventSortOption = .startDate) -> [CalendarEvent] {
        let allEvents = cachedPages.values
            .sorted { $0.pageNumber < $1.pageNumber }
            .flatMap { $0.events }
        
        return sortEvents(allEvents, by: sortBy)
    }
    
    /// Checks if we should preload the next page based on current position
    func shouldPreloadNextPage(currentIndex: Int) -> Bool {
        let totalLoadedEvents = cachedPages.values.reduce(0) { $0 + $1.events.count }
        return hasMorePages && 
               (totalLoadedEvents - currentIndex) <= PaginationConfig.preloadThreshold
    }
    
    /// Preloads the next page if conditions are met
    func preloadNextPageIfNeeded(
        currentIndex: Int,
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        sortBy: EventSortOption = .startDate
    ) async {
        
        if shouldPreloadNextPage(currentIndex: currentIndex) {
            print("🔄 CalendarPaginationManager: Preloading next page")
            
            do {
                _ = try await loadNextPage(
                    dateRange: dateRange,
                    userId: userId,
                    familyId: familyId,
                    privacyLevel: privacyLevel,
                    sortBy: sortBy
                )
            } catch {
                print("⚠️ CalendarPaginationManager: Failed to preload next page: \(error.localizedDescription)")
            }
        }
    }
    
    /// Resets pagination state
    func reset() {
        currentPage = 0
        cachedPages.removeAll()
        loadingPages.removeAll()
        hasMorePages = true
        totalItems = 0
        error = nil
        isLoading = false
        
        print("🔄 CalendarPaginationManager: Reset pagination state")
    }
    
    /// Gets pagination statistics
    func getPaginationStats() -> PaginationStats {
        let loadedEvents = cachedPages.values.reduce(0) { $0 + $1.events.count }
        let cachedPagesCount = cachedPages.count
        
        return PaginationStats(
            totalItems: totalItems,
            loadedItems: loadedEvents,
            currentPage: currentPage,
            cachedPages: cachedPagesCount,
            pageSize: pageSize,
            hasMorePages: hasMorePages,
            isLoading: isLoading
        )
    }
    
    // MARK: - Private Implementation
    
    private func loadEventsForPage(
        page: Int,
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        sortBy: EventSortOption
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
        
        // Create fetch descriptor with pagination
        var descriptor = FetchDescriptor<CalendarEvent>()
        if let predicate = combinedPredicate {
            descriptor.predicate = predicate
        }
        
        // Set sort order
        descriptor.sortBy = getSortDescriptors(for: sortBy)
        
        // Set pagination
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = page * pageSize
        
        // Fetch events
        let events = try modelContext.fetch(descriptor)
        
        return events
    }
    
    private func getTotalEventCount(
        dateRange: DateInterval,
        userId: UUID? = nil,
        familyId: UUID? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil
    ) async throws -> Int {
        
        // Use the same predicate logic as loadEventsForPage but without pagination
        var predicates: [Predicate<CalendarEvent>] = []
        
        predicates.append(#Predicate<CalendarEvent> { event in
            event.startDate >= dateRange.start && event.startDate <= dateRange.end
        })
        
        predicates.append(#Predicate<CalendarEvent> { event in
            !event.isDeleted
        })
        
        if let userId = userId {
            predicates.append(#Predicate<CalendarEvent> { event in
                event.createdBy == userId
            })
        }
        
        if let familyId = familyId {
            predicates.append(#Predicate<CalendarEvent> { event in
                event.familyId == familyId
            })
        }
        
        if let privacyLevel = privacyLevel {
            predicates.append(#Predicate<CalendarEvent> { event in
                event.privacyLevel == privacyLevel
            })
        }
        
        let combinedPredicate = predicates.reduce(nil) { result, predicate in
            if let result = result {
                return #Predicate<CalendarEvent> { event in
                    result.evaluate(event) && predicate.evaluate(event)
                }
            } else {
                return predicate
            }
        }
        
        var descriptor = FetchDescriptor<CalendarEvent>()
        if let predicate = combinedPredicate {
            descriptor.predicate = predicate
        }
        
        let allEvents = try modelContext.fetch(descriptor)
        return allEvents.count
    }
    
    private func getSortDescriptors(for sortOption: EventSortOption) -> [SortDescriptor<CalendarEvent>] {
        switch sortOption {
        case .startDate:
            return [SortDescriptor(\.startDate)]
        case .startDateDescending:
            return [SortDescriptor(\.startDate, order: .reverse)]
        case .title:
            return [SortDescriptor(\.title), SortDescriptor(\.startDate)]
        case .lastModified:
            return [SortDescriptor(\.lastModified, order: .reverse)]
        case .createdDate:
            return [SortDescriptor(\.createdAt, order: .reverse)]
        }
    }
    
    private func sortEvents(_ events: [CalendarEvent], by sortOption: EventSortOption) -> [CalendarEvent] {
        switch sortOption {
        case .startDate:
            return events.sorted { $0.startDate < $1.startDate }
        case .startDateDescending:
            return events.sorted { $0.startDate > $1.startDate }
        case .title:
            return events.sorted { 
                if $0.title == $1.title {
                    return $0.startDate < $1.startDate
                }
                return $0.title < $1.title
            }
        case .lastModified:
            return events.sorted { $0.lastModified > $1.lastModified }
        case .createdDate:
            return events.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    private func manageCacheSize() {
        // Remove oldest pages if we exceed the cache limit
        if cachedPages.count > PaginationConfig.maxCachedPages {
            let sortedPages = cachedPages.sorted { $0.value.timestamp < $1.value.timestamp }
            let pagesToRemove = sortedPages.prefix(cachedPages.count - PaginationConfig.maxCachedPages)
            
            for (pageNumber, _) in pagesToRemove {
                cachedPages.removeValue(forKey: pageNumber)
            }
            
            print("🗑️ CalendarPaginationManager: Removed \(pagesToRemove.count) old cached pages")
        }
    }
}

// MARK: - Supporting Types

/// Represents a paginated page of events
private struct PaginatedEventPage {
    let pageNumber: Int
    let events: [CalendarEvent]
    let timestamp: Date
}

/// Event sorting options for pagination
enum EventSortOption: String, CaseIterable {
    case startDate = "start_date"
    case startDateDescending = "start_date_desc"
    case title = "title"
    case lastModified = "last_modified"
    case createdDate = "created_date"
    
    var displayName: String {
        switch self {
        case .startDate:
            return "Start Date (Ascending)"
        case .startDateDescending:
            return "Start Date (Descending)"
        case .title:
            return "Title"
        case .lastModified:
            return "Last Modified"
        case .createdDate:
            return "Created Date"
        }
    }
}

/// Pagination statistics
struct PaginationStats {
    let totalItems: Int
    let loadedItems: Int
    let currentPage: Int
    let cachedPages: Int
    let pageSize: Int
    let hasMorePages: Bool
    let isLoading: Bool
    
    var loadedPercentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(loadedItems) / Double(totalItems)
    }
    
    var description: String {
        return """
        Pagination Stats:
        - Total Items: \(totalItems)
        - Loaded Items: \(loadedItems) (\(String(format: "%.1f", loadedPercentage * 100))%)
        - Current Page: \(currentPage)
        - Cached Pages: \(cachedPages)
        - Page Size: \(pageSize)
        - Has More: \(hasMorePages)
        - Loading: \(isLoading)
        """
    }
}