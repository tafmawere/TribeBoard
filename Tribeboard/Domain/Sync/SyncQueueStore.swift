import Foundation

final class SyncQueueStore {
    private struct SyncQueueEnvelope: Codable {
        let schemaVersion: Int
        let changes: [SyncChange]
    }
    
    private struct SyncOperationsEnvelope: Codable {
        let schemaVersion: Int
        let operations: [SyncOperation]
    }

    private let schemaVersion = 1
    private let fileName = "sync_queue.json"
    private let operationsFileName = "sync_operations_queue.json"
    private let fileStore: JSONFileStore

    init(fileStore: JSONFileStore = JSONFileStore()) {
        self.fileStore = fileStore
    }

    func load() -> [SyncChange] {
        guard fileStore.fileExists(fileName: fileName) else { return [] }
        do {
            let payload = try fileStore.load(SyncQueueEnvelope.self, from: fileName)
            guard payload.schemaVersion == schemaVersion else {
#if DEBUG
                print("SyncQueueStore.load -> schema mismatch for \(fileName): found \(payload.schemaVersion), expected \(schemaVersion). Returning empty.")
#endif
                return []
            }
            return payload.changes
        } catch {
            recoverCorruptFile()
            return []
        }
    }

    func save(_ changes: [SyncChange]) {
        let payload = SyncQueueEnvelope(schemaVersion: schemaVersion, changes: changes)
        do {
            try fileStore.save(payload, to: fileName)
        } catch {
#if DEBUG
            print("SyncQueueStore.save -> failed to save \(fileName): \(error)")
#endif
        }
    }
    
    func enqueue(operation: SyncOperation) {
        var operations = pendingOperations()
        operations = deduplicated(operations: operations, appending: operation)
        operations.append(operation)
        saveOperations(operations)
    }
    
    func dequeue(operationId: UUID) {
        let filtered = pendingOperations().filter { $0.id != operationId }
        saveOperations(filtered)
    }
    
    func pendingOperations() -> [SyncOperation] {
        guard fileStore.fileExists(fileName: operationsFileName) else { return [] }
        do {
            let payload = try fileStore.load(SyncOperationsEnvelope.self, from: operationsFileName)
            guard payload.schemaVersion == schemaVersion else {
#if DEBUG
                print("SyncQueueStore.pendingOperations -> schema mismatch for \(operationsFileName): found \(payload.schemaVersion), expected \(schemaVersion). Returning empty.")
#endif
                return []
            }
            return payload.operations
        } catch {
            recoverCorruptFile(fileName: operationsFileName)
            return []
        }
    }
    
    func pendingOperations(for householdId: UUID, entityType: SyncEntityType? = nil) -> [SyncOperation] {
        pendingOperations().filter { operation in
            guard operation.householdId == householdId else { return false }
            if let entityType {
                return operation.entityType == entityType
            }
            return true
        }
    }
    
    func oldestPendingOperation() -> SyncOperation? {
        pendingOperations().first
    }
    
    func groupedPendingCounts() -> [SyncEntityType: Int] {
        Dictionary(grouping: pendingOperations(), by: \.entityType).mapValues(\.count)
    }
    
    func clearCompleted() {
        saveOperations([])
    }
    
    private func saveOperations(_ operations: [SyncOperation]) {
        let payload = SyncOperationsEnvelope(schemaVersion: schemaVersion, operations: operations)
        do {
            try fileStore.save(payload, to: operationsFileName)
        } catch {
#if DEBUG
            print("SyncQueueStore.saveOperations -> failed to save \(operationsFileName): \(error)")
#endif
        }
    }
    
    private func deduplicated(operations: [SyncOperation], appending operation: SyncOperation) -> [SyncOperation] {
        var updated = operations
        updated.removeAll { existing in
            guard existing.householdId == operation.householdId else { return false }
            guard existing.entityType == operation.entityType else { return false }
            guard existing.entityId == operation.entityId else { return false }
            if operation.operationType == .delete {
                return true
            }
            return existing.operationType == operation.operationType
        }
        return updated
    }

    private func recoverCorruptFile() {
        recoverCorruptFile(fileName: fileName)
    }
    
    private func recoverCorruptFile(fileName: String) {
        guard let directory = try? fileStore.applicationSupportDirectoryURL() else { return }
        let sourceURL = directory.appendingPathComponent(fileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let corruptURL = directory.appendingPathComponent("\(fileName).corrupt-\(stamp).json", isDirectory: false)
        try? FileManager.default.moveItem(at: sourceURL, to: corruptURL)
#if DEBUG
        print("SyncQueueStore.load -> moved corrupt file to \(corruptURL.lastPathComponent)")
#endif
    }
}

