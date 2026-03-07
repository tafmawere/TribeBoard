import Foundation

struct JSONFileStore {
    private static let defaultDirectoryName = "TribeBoardData"
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let directoryName = JSONFileStore.defaultDirectoryName

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func save<T: Codable>(_ object: T, to fileName: String) throws {
        let url = try fileURL(for: fileName)
        let data = try encoder.encode(object)
        try atomicWrite(data, to: url)
    }

    func load<T: Codable>(_ type: T.Type, from fileName: String) throws -> T {
        let url = try fileURL(for: fileName)
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }

    func fileExists(fileName: String) -> Bool {
        do {
            let url = try fileURL(for: fileName)
            return fileManager.fileExists(atPath: url.path)
        } catch {
            return false
        }
    }

    func applicationSupportDirectoryURL() throws -> URL {
        let baseURL = try fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            .unwrap(or: CocoaError(.fileNoSuchFile))
        let directoryURL = baseURL.appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        return directoryURL
    }

    private func fileURL(for fileName: String) throws -> URL {
        try applicationSupportDirectoryURL().appendingPathComponent(fileName, isDirectory: false)
    }

    private func atomicWrite(_ data: Data, to destinationURL: URL) throws {
        let directory = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let tempURL = directory.appendingPathComponent(".\(destinationURL.lastPathComponent).tmp-\(UUID().uuidString)")
        try data.write(to: tempURL, options: [])

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: destinationURL)
            }
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            try fileManager.moveItem(at: tempURL, to: destinationURL)
        }
    }

    static func debugStorageDirectory() -> URL {
        let manager = FileManager.default
        let baseURL = manager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? manager.temporaryDirectory
        let directoryURL = baseURL.appendingPathComponent(defaultDirectoryName, isDirectory: true)
        if !manager.fileExists(atPath: directoryURL.path) {
            try? manager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        return directoryURL
    }
}

private extension Optional {
    func unwrap(or error: Error) throws -> Wrapped {
        guard let value = self else { throw error }
        return value
    }
}
