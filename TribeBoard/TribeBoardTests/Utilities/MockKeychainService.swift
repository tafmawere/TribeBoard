import Foundation
@testable import TribeBoard

/// Mock implementation of KeychainService for testing purposes
/// Provides configurable error scenarios and in-memory data persistence simulation
class MockKeychainService {
    
    // MARK: - Configuration Properties
    
    /// Controls whether operations should succeed or fail
    var shouldSucceed: Bool = true
    
    /// The error to throw when shouldSucceed is false
    var errorToThrow: KeychainService.KeychainError = .unexpectedError(errSecInternalError)
    
    /// Controls which specific operations should fail
    var failingOperations: Set<Operation> = []
    
    /// In-memory storage to simulate keychain persistence
    private var storage: [String: Data] = [:]
    
    /// Call tracking for test verification
    private(set) var storeCallCount = 0
    private(set) var retrieveCallCount = 0
    private(set) var deleteCallCount = 0
    
    // MARK: - Operation Types
    
    enum Operation {
        case store
        case retrieve
        case delete
        case storeAppleUserId
        case retrieveAppleUserId
        case storeAppleUserIdHash
        case retrieveAppleUserIdHash
        case storeFamilyId
        case retrieveFamilyId
        case deleteAppleUserId
        case deleteAppleUserIdHash
        case deleteFamilyId
        case clearAll
    }
    
    // MARK: - Test Configuration Methods
    
    /// Reset the mock to its default state
    func reset() {
        shouldSucceed = true
        errorToThrow = .unexpectedError(errSecInternalError)
        failingOperations.removeAll()
        storage.removeAll()
        storeCallCount = 0
        retrieveCallCount = 0
        deleteCallCount = 0
    }
    
    /// Configure the mock to fail for specific operations
    /// - Parameter operations: The operations that should fail
    func setFailingOperations(_ operations: Set<Operation>) {
        failingOperations = operations
    }
    
    /// Configure the mock to throw a specific error
    /// - Parameter error: The error to throw when operations fail
    func setError(_ error: KeychainService.KeychainError) {
        errorToThrow = error
    }
    
    /// Pre-populate the mock storage with test data
    /// - Parameters:
    ///   - data: The data to store
    ///   - key: The key to associate with the data
    func prePopulate(data: Data, for key: String) {
        storage[key] = data
    }
    
    /// Get all stored data for inspection in tests
    /// - Returns: Dictionary of all stored key-value pairs
    func getAllStoredData() -> [String: Data] {
        return storage
    }
    
    /// Check if a specific key exists in storage
    /// - Parameter key: The key to check
    /// - Returns: True if the key exists, false otherwise
    func hasData(for key: String) -> Bool {
        return storage[key] != nil
    }
    
    /// Get the number of items stored
    /// - Returns: The count of stored items
    func getStoredItemCount() -> Int {
        return storage.count
    }
    
    // MARK: - Private Helper Methods
    
    private func shouldFailOperation(_ operation: Operation) -> Bool {
        return !shouldSucceed || failingOperations.contains(operation)
    }
    
    private func throwErrorIfNeeded(for operation: Operation) throws {
        if shouldFailOperation(operation) {
            throw errorToThrow
        }
    }
    
    // MARK: - KeychainService Interface Implementation
    
    /// Store data securely in the mock keychain
    /// - Parameters:
    ///   - data: The data to store
    ///   - key: The key to associate with the data
    /// - Throws: KeychainError if configured to fail
    func store(_ data: Data, for key: String) throws {
        storeCallCount += 1
        try throwErrorIfNeeded(for: .store)
        storage[key] = data
    }
    
    /// Retrieve data from the mock keychain
    /// - Parameter key: The key associated with the data
    /// - Returns: The stored data, or nil if not found
    /// - Throws: KeychainError if configured to fail
    func retrieve(for key: String) throws -> Data? {
        retrieveCallCount += 1
        try throwErrorIfNeeded(for: .retrieve)
        return storage[key]
    }
    
    /// Delete data from the mock keychain
    /// - Parameter key: The key associated with the data to delete
    /// - Throws: KeychainError if configured to fail
    func delete(for key: String) throws {
        deleteCallCount += 1
        try throwErrorIfNeeded(for: .delete)
        storage.removeValue(forKey: key)
    }
    
    // MARK: - Convenience Methods for App-Specific Data
    
    /// Store Apple User ID securely
    /// - Parameter userId: The Apple User ID to store
    /// - Throws: KeychainError if configured to fail
    func storeAppleUserId(_ userId: String) throws {
        try throwErrorIfNeeded(for: .storeAppleUserId)
        guard let data = userId.data(using: .utf8) else {
            throw KeychainService.KeychainError.invalidData
        }
        try store(data, for: KeychainService.appleUserIdKey)
    }
    
    /// Retrieve Apple User ID
    /// - Returns: The stored Apple User ID, or nil if not found
    /// - Throws: KeychainError if configured to fail
    func retrieveAppleUserId() throws -> String? {
        try throwErrorIfNeeded(for: .retrieveAppleUserId)
        guard let data = try retrieve(for: KeychainService.appleUserIdKey) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    /// Store Apple User ID hash securely
    /// - Parameter hash: The Apple User ID hash to store
    /// - Throws: KeychainError if configured to fail
    func storeAppleUserIdHash(_ hash: String) throws {
        try throwErrorIfNeeded(for: .storeAppleUserIdHash)
        guard let data = hash.data(using: .utf8) else {
            throw KeychainService.KeychainError.invalidData
        }
        try store(data, for: KeychainService.appleUserIdHashKey)
    }
    
    /// Retrieve Apple User ID hash
    /// - Returns: The stored Apple User ID hash, or nil if not found
    /// - Throws: KeychainError if configured to fail
    func retrieveAppleUserIdHash() throws -> String? {
        try throwErrorIfNeeded(for: .retrieveAppleUserIdHash)
        guard let data = try retrieve(for: KeychainService.appleUserIdHashKey) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    /// Store current family ID securely
    /// - Parameter familyId: The family ID to store
    /// - Throws: KeychainError if configured to fail
    func storeFamilyId(_ familyId: UUID) throws {
        try throwErrorIfNeeded(for: .storeFamilyId)
        let data = familyId.uuidString.data(using: .utf8)!
        try store(data, for: KeychainService.familyIdKey)
    }
    
    /// Retrieve current family ID
    /// - Returns: The stored family ID, or nil if not found
    /// - Throws: KeychainError if configured to fail
    func retrieveFamilyId() throws -> UUID? {
        try throwErrorIfNeeded(for: .retrieveFamilyId)
        guard let data = try retrieve(for: KeychainService.familyIdKey),
              let uuidString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return UUID(uuidString: uuidString)
    }
    
    /// Delete Apple User ID from mock keychain
    /// - Throws: KeychainError if configured to fail
    func deleteAppleUserId() throws {
        try throwErrorIfNeeded(for: .deleteAppleUserId)
        try delete(for: KeychainService.appleUserIdKey)
    }
    
    /// Delete Apple User ID hash from mock keychain
    /// - Throws: KeychainError if configured to fail
    func deleteAppleUserIdHash() throws {
        try throwErrorIfNeeded(for: .deleteAppleUserIdHash)
        try delete(for: KeychainService.appleUserIdHashKey)
    }
    
    /// Delete family ID from mock keychain
    /// - Throws: KeychainError if configured to fail
    func deleteFamilyId() throws {
        try throwErrorIfNeeded(for: .deleteFamilyId)
        try delete(for: KeychainService.familyIdKey)
    }
    
    /// Clear all app-specific data from mock keychain
    /// - Throws: KeychainError if configured to fail
    func clearAll() throws {
        try throwErrorIfNeeded(for: .clearAll)
        try deleteAppleUserId()
        try deleteAppleUserIdHash()
        try deleteFamilyId()
    }
    
    // MARK: - State Management Extensions
    
    /// Response delay for performance testing
    private var responseDelay: TimeInterval = 0.0
    
    /// Whether the service is configured for testing
    var isConfigured: Bool = true
    
    /// Set mock error for testing
    func setMockError(_ error: KeychainService.KeychainError) {
        errorToThrow = error
        shouldSucceed = false
    }
    
    /// Set response delay for performance testing
    func setResponseDelay(_ delay: TimeInterval) {
        responseDelay = delay
    }
    
    /// Restore data from snapshot
    func restoreData(_ data: [String: Data]) {
        storage = data
    }
    
    /// Get call counts for test verification
    /// - Returns: Dictionary of operation names to call counts
    func getCallCounts() -> [String: Int] {
        return [
            "store": storeCallCount,
            "retrieve": retrieveCallCount,
            "delete": deleteCallCount
        ]
    }
}