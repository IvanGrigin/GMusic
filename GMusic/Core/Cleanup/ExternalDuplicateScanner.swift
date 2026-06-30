import Foundation

struct ExternalDuplicateMatch {
    let fileURL: URL
    let matchingTrackID: UUID
    let hash: String
}

/// Scans a user-chosen folder (e.g. Downloads) for files that are byte-identical
/// to a track already in the library, so they can be offered up for cleanup.
/// Never looks inside the app's own library directory.
struct ExternalDuplicateScanner {
    let fileStorage: FileStorage
    let fileHashingService: FileHashingService
    let trackRepository: TrackRepository

    func findDuplicates(in folderURL: URL) async throws -> [ExternalDuplicateMatch] {
        let knownHashes = try await trackRepository.listAllHashes()
        guard !knownHashes.isEmpty else { return [] }

        let candidates = ImportScanner().findAudioFiles(in: folderURL)
            .filter { !fileStorage.isInsideAppLibrary(url: $0) }

        var matches: [ExternalDuplicateMatch] = []
        for url in candidates {
            guard let hash = try? await fileHashingService.sha256Async(url: url),
                  knownHashes.contains(hash),
                  let track = try await trackRepository.track(byHash: hash) else { continue }
            matches.append(ExternalDuplicateMatch(fileURL: url, matchingTrackID: track.id, hash: hash))
        }
        return matches
    }
}
