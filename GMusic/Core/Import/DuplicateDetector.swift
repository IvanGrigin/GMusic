import Foundation

struct DuplicateDetector {
    private let trackRepository: TrackRepository

    init(trackRepository: TrackRepository) {
        self.trackRepository = trackRepository
    }

    /// Exact-duplicate rule for the MVP: identical SHA-256 hash.
    func findExactDuplicate(hash: String) async throws -> Track? {
        try await trackRepository.track(byHash: hash)
    }
}
