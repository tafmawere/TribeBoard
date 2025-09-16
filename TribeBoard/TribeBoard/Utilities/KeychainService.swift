import Foundation
import Security

/// Service for secure storage and retrieval of sensitive data using iOS Keychain
class KeychainService {
    
    // MARK: - Keychain Keys
    static let appleUserIdHashKey = "com.tribeboard.appleUserIdHash"
    static let familyIdKey = "com.tribeboard.familyId"
    
    // MARK: - Keychain Errors
    enum KeychainError: LocalizedError {
        case itemNotFound
        case duplicateItem
        case invalidData
        case unexpectedError(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "Item not found in Keychain"
            case .duplicateItem:
                return "Item already exists in Keychain"
            case .invalidData:
                return "Invalid data format"
            case .unexpectedError(let status):
                return "Keychain error: \(status)"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Store data securely in the Keychain
    /// - Parameters:
    ///   - data: The data to store
    ///   - key: The key to associate with the data
    /// - Throws: KeychainError if the operation fails
    func store(_ data: Data, for key: String) throws {
        // First, try to delete any existing item with the same key
        try? delete(for: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            } else {
                throw KeychainError.unexpectedError(status)
            }
        }
    }
    
    /// Retrieve data from the Keychain
    /// - Parameter key: The key associated with the data
    /// - Returns: The stored data, or nil if not found
    /// - Throws: KeychainError if the operation fails
    func retrieve(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedError(status)
        }
    }
    
    /// Delete data from the Keychain
    /// - Parameter key: The key associated with the data to delete
    /// - Throws: KeychainError if the operation fails
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    // MARK: - Convenience Methods for App-Specific Data
    
    /// Store Apple User ID hash securely
    /// - Parameter hash: The Apple User ID hash to store
    /// - Throws: KeychainError if the operation fails
    func storeAppleUserIdHash(_ hash: String) throws {
        guard let data = hash.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try store(data, for: Self.appleUserIdHashKey)
    }
    
    /// Retrieve Apple User ID hash
    /// - Returns: The stored Apple User ID hash, or nil if not found
    /// - Throws: KeychainError if the operation fails
    func retrieveAppleUserIdHash() throws -> String? {
        guard let data = try retrieve(for: Self.appleUserIdHashKey) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    /// Store current family ID securely
    /// - Parameter familyId: The family ID to store
    /// - Throws: KeychainError if the operation fails
    func storeFamilyId(_ familyId: UUID) throws {
        let data = familyId.uuidString.data(using: .utf8)!
        try store(data, for: Self.familyIdKey)
    }
    
    /// Retrieve current family ID
    /// - Returns: The stored family ID, or nil if not found
    /// - Throws: KeychainError if the operation fails
    func retrieveFamilyId() throws -> UUID? {
        guard let data = try retrieve(for: Self.familyIdKey),
              let uuidString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return UUID(uuidString: uuidString)
    }
    
    /// Delete Apple User ID hash from Keychain
    /// - Throws: KeychainError if the operation fails
    func deleteAppleUserIdHash() throws {
        try delete(for: Self.appleUserIdHashKey)
    }
    
    /// Delete family ID from Keychain
    /// - Throws: KeychainError if the operation fails
    func deleteFamilyId() throws {
        try delete(for: Self.familyIdKey)
    }
    
    /// Clear all app-specific data from Keychain
    /// - Throws: KeychainError if any operation fails
    func clearAll() throws {
        try deleteAppleUserIdHash()
        try deleteFamilyId()
    }
}