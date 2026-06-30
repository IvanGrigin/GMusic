import Foundation

struct ExternalDuplicateCleanupResult {
    let deleted: [URL]
    let failed: [(URL, Error)]
}

/// Deletes files found by ExternalDuplicateScanner, reusing the exact same
/// safety checks as SourceDeletionService: never delete inside the app
/// library, and only delete after re-verifying the hash against the
/// library copy that's about to remain as the single source of truth.
struct ExternalDuplicateCleaner {
    let fileStorage: FileStorage
    let fileHashingService: FileHashingService
    let trackRepository: TrackRepository
    let sourceDeletionService: SourceDeletionService

    func deleteDuplicates(_ matches: [ExternalDuplicateMatch]) async -> ExternalDuplicateCleanupResult {
        var deleted: [URL] = []
        var failed: [(URL, Error)] = []

        for match in matches {
            do {
                guard let track = try await trackRepository.fetchTrack(id: match.matchingTrackID) else {
                    throw SourceDeletionError.libraryFileMissing
                }
                try await sourceDeletionService.deleteSourceIfSafe(
                    sourceURL: match.fileURL,
                    expectedHash: match.hash,
                    libraryRelativePath: track.fileRelativePath
                )
                deleted.append(match.fileURL)
            } catch {
                failed.append((match.fileURL, error))
            }
        }
        return ExternalDuplicateCleanupResult(deleted: deleted, failed: failed)
    }
}
