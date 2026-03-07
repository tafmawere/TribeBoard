import Foundation

struct JSONExportResult {
    let exportDirectory: URL
    let exportedFiles: [URL]
}

struct JSONExportService {
    struct ExportOptions {
        var includeRuns: Bool = true
        var includeSchedules: Bool = true
        var includeDrivers: Bool = true
    }

    private let fileManager: FileManager
    private let sourceDirectory: URL

    init(
        fileManager: FileManager = .default,
        sourceDirectory: URL = JSONFileStore.debugStorageDirectory()
    ) {
        self.fileManager = fileManager
        self.sourceDirectory = sourceDirectory
    }

    func export(options: ExportOptions = ExportOptions()) throws -> JSONExportResult {
        let stamp = timestampString()
        let exportDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("tribeboard-export-\(stamp)", isDirectory: true)
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        var exportedFiles: [URL] = []
        for fileName in fileNames(for: options) {
            let sourceURL = sourceDirectory.appendingPathComponent(fileName, isDirectory: false)
            guard fileManager.fileExists(atPath: sourceURL.path) else { continue }
            let destinationURL = exportDirectory.appendingPathComponent(fileName, isDirectory: false)
            try? fileManager.removeItem(at: destinationURL)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            exportedFiles.append(destinationURL)
        }

        return JSONExportResult(
            exportDirectory: exportDirectory,
            exportedFiles: exportedFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
        )
    }

    private func fileNames(for options: ExportOptions) -> [String] {
        var names: [String] = []
        if options.includeRuns { names.append("run_instances.json") }
        if options.includeSchedules { names.append("schedule_templates.json") }
        if options.includeDrivers { names.append("drivers.json") }
        return names
    }

    private func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
