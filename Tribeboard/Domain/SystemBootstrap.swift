import Foundation

final class SystemBootstrap {
    // Intentionally not auto-run at launch yet; this is a controlled hook
    // until onboarding and scheduling lifecycle integration is finalized.
    static func runDailyGeneration() {
        let scheduleStore = ScheduleStore()
        let runStore = RunStore()
        let generator = RunGeneratorService()

        let templates = scheduleStore.load()
        let existingRuns = runStore.load()

        let newRuns = generator.generateRuns(
            from: templates,
            existingRuns: existingRuns,
            daysAhead: 14
        )

        if !newRuns.isEmpty {
            let updatedRuns = existingRuns + newRuns
            runStore.save(updatedRuns)
        }
    }

    // Debug-only style helper to manually seed and generate on demand.
    // Keeping it explicit avoids unintentional data creation on app launch.
    static func debugSeedAndGenerate(daysAhead: Int = 14) -> (seeded: Bool, newRuns: Int) {
        let scheduleStore = ScheduleStore()
        let runStore = RunStore()
        let generator = RunGeneratorService()

        let templates = scheduleStore.load()
        let existingRuns = runStore.load()
        let newRuns = generator.generateRuns(
            from: templates,
            existingRuns: existingRuns,
            daysAhead: daysAhead
        )

        if !newRuns.isEmpty {
            runStore.save(existingRuns + newRuns)
        }

#if DEBUG
        let storageURL = JSONFileStore.debugStorageDirectory()
        print("SystemBootstrap debug -> storage: \(storageURL.path), existing: \(existingRuns.count), generated: \(newRuns.count), savedTotal: \(existingRuns.count + newRuns.count)")
#endif

        return (seeded: false, newRuns: newRuns.count)
    }

    static func generateAndPersistRuns(daysAhead: Int = 14) async throws -> Int {
        let scheduleStore = ScheduleStore()
        let runStore = RunStore()
        let generator = RunGeneratorService()

        let templates = scheduleStore.load()
        let existingRuns = runStore.load()
        let newRuns = generator.generateRuns(
            from: templates,
            existingRuns: existingRuns,
            daysAhead: daysAhead
        )

        if !newRuns.isEmpty {
            runStore.save(existingRuns + newRuns)
        }
#if DEBUG
        let storageURL = JSONFileStore.debugStorageDirectory()
        print("SystemBootstrap.generateAndPersistRuns -> storage: \(storageURL.path), existing: \(existingRuns.count), generated: \(newRuns.count)")
#endif

        return newRuns.count
    }

    static func clearAllRuns() async throws {
        let runStore = RunStore()
        runStore.save([])
    }

    static func clearAllSchedules() async throws {
        let scheduleStore = ScheduleStore()
        scheduleStore.save([])
    }

    static func seedDemoSchedules() async throws {
        // Sprint 40: explicitly disabled to prevent placeholder schedule sources.
    }
}
