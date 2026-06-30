import Foundation

enum SourceDeletionError: Error, LocalizedError {
    case sourceInsideAppLibrary
    case hashMismatch
    case libraryFileMissing

    var errorDescription: String? {
        switch self {
        case .sourceInsideAppLibrary: return "Refusing to delete a file inside the app library"
        case .hashMismatch: return "Source file no longer matches the imported copy"
        case .libraryFileMissing: return "The library copy is missing; refusing to delete the source"
        }
    }
}

/// The only place in the app allowed to delete a source file outside the library.
/// Every check here must pass before a single byte is removed.
struct SourceDeletionService {
    let fileStorage: FileStorage
    let fileHashingService: FileHashingService

    func deleteSourceIfSafe(sourceURL: URL, expectedHash: String, libraryRelativePath: String) async throws {
        guard !fileStorage.isInsideAppLibrary(url: sourceURL) else {
            throw SourceDeletionError.sourceInsideAppLibrary
        }
        guard fileStorage.fileExists(relativePath: libraryRelativePath) else {
            throw SourceDeletionError.libraryFileMissing
        }
        let sourceHash = try await fileHashingService.sha256Async(url: sourceURL)
        guard sourceHash == expectedHash else {
            throw SourceDeletionError.hashMismatch
        }
        try FileManager.default.removeItem(at: sourceURL)
    }
}
