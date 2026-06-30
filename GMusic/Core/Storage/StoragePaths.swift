import Foundation

struct StoragePaths {
    let root: URL
    let audioDirectory: URL
    let artworkDirectory: URL
    let databaseDirectory: URL
    let importsStagingDirectory: URL
    let cacheDirectory: URL

    static func makeDefault(fileManager: FileManager = .default) throws -> StoragePaths {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = appSupport.appendingPathComponent("GMusic", isDirectory: true)
        return StoragePaths(
            root: root,
            audioDirectory: root.appendingPathComponent("Audio", isDirectory: true),
            artworkDirectory: root.appendingPathComponent("Artwork", isDirectory: true),
            databaseDirectory: root.appendingPathComponent("Database", isDirectory: true),
            importsStagingDirectory: root.appendingPathComponent("Imports/Staging", isDirectory: true),
            cacheDirectory: root.appendingPathComponent("Cache", isDirectory: true)
        )
    }

    func createDirectoriesIfNeeded(fileManager: FileManager = .default) throws {
        for url in [root, audioDirectory, artworkDirectory, databaseDirectory, importsStagingDirectory, cacheDirectory] {
            if !fileManager.fileExists(atPath: url.path) {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }
}
