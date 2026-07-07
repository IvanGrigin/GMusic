import Foundation

enum FileStorageError: Error {
    case copyFailed
    case moveFailed
    case fileNotFound
}

/// All audio lives under `StoragePaths.root`. Nothing outside that root is ever
/// considered part of the library, which is what makes safe source-deletion and
/// external-duplicate cleanup possible (see SourceDeletionService / CleanupSafetyValidator).
final class FileStorage {
    let paths: StoragePaths
    private let fileManager: FileManager

    init(paths: StoragePaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func copyToStaging(sourceURL: URL) throws -> URL {
        let stagingURL = paths.importsStagingDirectory
            .appendingPathComponent(UUID().uuidString + "-" + sourceURL.lastPathComponent)
        if fileManager.fileExists(atPath: stagingURL.path) {
            try fileManager.removeItem(at: stagingURL)
        }
        try fileManager.copyItem(at: sourceURL, to: stagingURL)
        return stagingURL
    }

    func moveStagingToLibrary(stagingURL: URL, trackID: UUID, fileExtension: String) throws -> String {
        let fileName = "\(trackID.uuidString).\(fileExtension.lowercased())"
        let destinationURL = paths.audioDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: stagingURL, to: destinationURL)
        return "Audio/\(fileName)"
    }

    func removeStagingFile(at url: URL) {
        try? fileManager.removeItem(at: url)
    }

    func deleteAudio(relativePath: String) throws {
        let url = absoluteURL(forRelativePath: relativePath)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func fileExists(relativePath: String) -> Bool {
        fileManager.fileExists(atPath: absoluteURL(forRelativePath: relativePath).path)
    }

    func absoluteURL(forRelativePath relativePath: String) -> URL {
        paths.root.appendingPathComponent(relativePath)
    }

    /// Used by cleanup to guarantee we only ever delete files outside the app library.
    func isInsideAppLibrary(url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(paths.root.standardizedFileURL.path)
    }

    func sizeOfDirectory(_ url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
