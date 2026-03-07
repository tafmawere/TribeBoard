import Foundation

enum SyncChangeFactory {
    static func makeRunChange(
        householdId: UUID,
        entityId: UUID,
        operation: SyncOperationType,
        now: Date = Date()
    ) -> SyncChange {
        makeChange(
            householdId: householdId,
            entityType: .run,
            entityId: entityId,
            operation: operation,
            now: now
        )
    }

    static func makeScheduleChange(
        householdId: UUID,
        entityId: UUID,
        operation: SyncOperationType,
        now: Date = Date()
    ) -> SyncChange {
        makeChange(
            householdId: householdId,
            entityType: .schedule,
            entityId: entityId,
            operation: operation,
            now: now
        )
    }

    static func makeDriverChange(
        householdId: UUID,
        entityId: UUID,
        operation: SyncOperationType,
        now: Date = Date()
    ) -> SyncChange {
        makeChange(
            householdId: householdId,
            entityType: .driver,
            entityId: entityId,
            operation: operation,
            now: now
        )
    }

    static func makeHouseholdChange(
        householdId: UUID,
        entityId: UUID,
        operation: SyncOperationType,
        now: Date = Date()
    ) -> SyncChange {
        makeChange(
            householdId: householdId,
            entityType: .household,
            entityId: entityId,
            operation: operation,
            now: now
        )
    }

    private static func makeChange(
        householdId: UUID,
        entityType: SyncEntityType,
        entityId: UUID,
        operation: SyncOperationType,
        now: Date
    ) -> SyncChange {
        SyncChange(
            id: UUID(),
            householdId: householdId,
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            createdAt: now,
            retryCount: 0,
            lastTriedAt: nil,
            payloadVersion: 1,
            sourceDeviceId: DeviceIdentity.current,
            sourceRevision: 1,
            effectiveUpdatedAt: now
        )
    }
}

