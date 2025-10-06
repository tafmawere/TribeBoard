import SwiftUI
import Combine

/// Performance optimization utilities for SwiftUI views
struct PerformanceOptimization {
    
    /// Debounce publisher for reducing frequent updates
    static func debounce<T>(_ publisher: Published<T>.Publisher, for interval: TimeInterval = 0.3) -> AnyPublisher<T, Never> {
        publisher
            .debounce(for: .seconds(interval), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    /// Throttle publisher for limiting update frequency
    static func throttle<T>(_ publisher: Published<T>.Publisher, for interval: TimeInterval = 0.1) -> AnyPublisher<T, Never> {
        publisher
            .throttle(for: .seconds(interval), scheduler: RunLoop.main, latest: true)
            .eraseToAnyPublisher()
    }
}

/// View modifier for optimizing list performance
struct OptimizedList: ViewModifier {
    let itemCount: Int
    
    func body(content: Content) -> some View {
        if itemCount > 20 {
            // Use LazyVStack for large lists
            ScrollView {
                LazyVStack(spacing: 8) {
                    content
                }
            }
        } else {
            // Use regular VStack for small lists
            ScrollView {
                VStack(spacing: 8) {
                    content
                }
            }
        }
    }
}

extension View {
    /// Apply performance optimizations based on list size
    func optimizedList(itemCount: Int) -> some View {
        modifier(OptimizedList(itemCount: itemCount))
    }
}

/// Memory-efficient image loading for avatars and icons
struct OptimizedAsyncImage: View {
    let url: URL?
    let placeholder: Image
    let size: CGSize
    
    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholder
                        .foregroundColor(.secondary)
                }
            } else {
                placeholder
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(Circle())
    }
}

/// Efficient state management for complex forms
@MainActor
class OptimizedFormState: ObservableObject {
    @Published var isValid: Bool = false
    @Published var errors: [String: String] = [:]
    
    private var validationCancellables = Set<AnyCancellable>()
    
    /// Add validation for a field with debouncing
    func addValidation<T>(
        for keyPath: KeyPath<OptimizedFormState, Published<T>.Publisher>,
        fieldName: String,
        validator: @escaping (T) -> ValidationState
    ) {
        self[keyPath: keyPath]
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .map { value in
                let validation = validator(value)
                return (fieldName, validation)
            }
            .sink { [weak self] fieldName, validation in
                self?.updateValidation(for: fieldName, validation: validation)
            }
            .store(in: &validationCancellables)
    }
    
    private func updateValidation(for field: String, validation: ValidationState) {
        if let errorMessage = validation.errorMessage {
            errors[field] = errorMessage
        } else {
            errors.removeValue(forKey: field)
        }
        
        isValid = errors.isEmpty
    }
}

/// Efficient animation utilities that respect accessibility settings
struct OptimizedAnimations {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    static func spring(reduceMotion: Bool = false) -> Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.3)
        } else {
            return .spring(response: 0.5, dampingFraction: 0.8)
        }
    }
    
    static func easeInOut(reduceMotion: Bool = false) -> Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.2)
        } else {
            return .easeInOut(duration: 0.3)
        }
    }
    
    static func bouncy(reduceMotion: Bool = false) -> Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.3)
        } else {
            return .spring(response: 0.6, dampingFraction: 0.7)
        }
    }
}

/// View modifier for efficient view updates
struct EfficientUpdate: ViewModifier {
    let id: AnyHashable
    
    func body(content: Content) -> some View {
        content
            .id(id)
            .animation(.easeInOut(duration: 0.2), value: id)
    }
}

extension View {
    /// Mark view for efficient updates when identifier changes
    func efficientUpdate(id: AnyHashable) -> some View {
        modifier(EfficientUpdate(id: id))
    }
}

/// Lazy loading container for expensive views
struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}

/// Memory-efficient data loading for large datasets
@MainActor
class PaginatedDataLoader<T>: ObservableObject {
    @Published var items: [T] = []
    @Published var isLoading = false
    @Published var hasMoreData = true
    
    private let pageSize: Int
    private let loadData: (Int, Int) async throws -> [T]
    private var currentPage = 0
    
    init(pageSize: Int = 20, loadData: @escaping (Int, Int) async throws -> [T]) {
        self.pageSize = pageSize
        self.loadData = loadData
    }
    
    func loadNextPage() async {
        guard !isLoading && hasMoreData else { return }
        
        isLoading = true
        
        do {
            let newItems = try await loadData(currentPage * pageSize, pageSize)
            
            if newItems.count < pageSize {
                hasMoreData = false
            }
            
            items.append(contentsOf: newItems)
            currentPage += 1
        } catch {
            // Handle error
            print("Failed to load data: \(error)")
        }
        
        isLoading = false
    }
    
    func refresh() async {
        currentPage = 0
        hasMoreData = true
        items.removeAll()
        await loadNextPage()
    }
}