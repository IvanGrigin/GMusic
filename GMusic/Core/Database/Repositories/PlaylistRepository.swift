import Foundation
import SwiftData

@ModelActor
actor PlaylistRepository {
    func createPlaylist(_ playlist: Playlist) throws {
        modelContext.insert(playlist)
        try modelContext.save()
    }

    func updatePlaylist(id: UUID, mutate: (Playlist) -> Void) throws {
        guard let playlist = try fetchPlaylist(id: id) else { return }
        mutate(playlist)
        playlist.updatedAt = .now
        try modelContext.save()
    }

    func deletePlaylist(id: UUID) throws {
        guard let playlist = try fetchPlaylist(id: id) else { return }
        modelContext.delete(playlist)
        try modelContext.save()
    }

    func fetchPlaylist(id: UUID) throws -> Playlist? {
        var descriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func listPlaylists() throws -> [Playlist] {
        var descriptor = FetchDescriptor<Playlist>()
        descriptor.sortBy = [SortDescriptor(\.title)]
        return try modelContext.fetch(descriptor)
    }

    func addTrack(_ trackID: UUID, toPlaylist playlistID: UUID) throws {
        guard let playlist = try fetchPlaylist(id: playlistID), !playlist.trackIDs.contains(trackID) else { return }
        playlist.trackIDs.append(trackID)
        playlist.updatedAt = .now
        try modelContext.save()
    }

    func removeTrack(_ trackID: UUID, fromPlaylist playlistID: UUID) throws {
        guard let playlist = try fetchPlaylist(id: playlistID) else { return }
        playlist.trackIDs.removeAll { $0 == trackID }
        playlist.updatedAt = .now
        try modelContext.save()
    }

    func reorderTracks(in playlistID: UUID, to newOrder: [UUID]) throws {
        guard let playlist = try fetchPlaylist(id: playlistID) else { return }
        playlist.trackIDs = newOrder
        playlist.updatedAt = .now
        try modelContext.save()
    }
}
