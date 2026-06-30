import Foundation
import SwiftData

enum TrackSortOption {
    case titleAscending
    case artistAscending
    case recentlyImported
}

@ModelActor
actor TrackRepository {
    func createTrack(_ track: Track) throws {
        modelContext.insert(track)
        try modelContext.save()
    }

    func updateTrack(id: UUID, mutate: (Track) -> Void) throws {
        guard let track = try fetchTrack(id: id) else { return }
        mutate(track)
        try modelContext.save()
    }

    func deleteTrack(id: UUID) throws {
        guard let track = try fetchTrack(id: id) else { return }
        modelContext.delete(track)
        try modelContext.save()
    }

    func fetchTrack(id: UUID) throws -> Track? {
        var descriptor = FetchDescriptor<Track>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func track(byHash hash: String) throws -> Track? {
        var descriptor = FetchDescriptor<Track>(predicate: #Predicate { $0.fileHashSHA256 == hash })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func listAllHashes() throws -> Set<String> {
        Set(try modelContext.fetch(FetchDescriptor<Track>()).map(\.fileHashSHA256))
    }

    func listTracks(sortedBy sort: TrackSortOption = .titleAscending) throws -> [Track] {
        var descriptor = FetchDescriptor<Track>()
        switch sort {
        case .titleAscending:
            descriptor.sortBy = [SortDescriptor(\.title)]
        case .artistAscending:
            descriptor.sortBy = [SortDescriptor(\.artistName)]
        case .recentlyImported:
            descriptor.sortBy = [SortDescriptor(\.dateImported, order: .reverse)]
        }
        return try modelContext.fetch(descriptor)
    }

    func listTracks(albumID: UUID) throws -> [Track] {
        var descriptor = FetchDescriptor<Track>(predicate: #Predicate { $0.albumID == albumID })
        descriptor.sortBy = [SortDescriptor(\.discNumber), SortDescriptor(\.trackNumber)]
        return try modelContext.fetch(descriptor)
    }

    /// Resolves track IDs in the given order (used by playlists, where order matters).
    func listTracks(ids: [UUID]) throws -> [Track] {
        let descriptor = FetchDescriptor<Track>(predicate: #Predicate { ids.contains($0.id) })
        let tracks = try modelContext.fetch(descriptor)
        let order = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        return tracks.sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
    }

    func incrementPlayCount(id: UUID) throws {
        guard let track = try fetchTrack(id: id) else { return }
        track.playCount += 1
        track.lastPlayedAt = .now
        try modelContext.save()
    }
}
