import Foundation
import SwiftData

@ModelActor
actor AlbumRepository {
    func findOrCreateAlbum(title: String, artistName: String) throws -> UUID {
        var descriptor = FetchDescriptor<Album>(
            predicate: #Predicate { $0.title == title && $0.artistName == artistName }
        )
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            return existing.id
        }
        let album = Album(title: title, artistName: artistName)
        modelContext.insert(album)
        try modelContext.save()
        return album.id
    }

    func updateAlbum(id: UUID, mutate: (Album) -> Void) throws {
        guard let album = try fetchAlbum(id: id) else { return }
        mutate(album)
        album.updatedAt = .now
        try modelContext.save()
    }

    func deleteAlbum(id: UUID) throws {
        guard let album = try fetchAlbum(id: id) else { return }
        modelContext.delete(album)
        try modelContext.save()
    }

    func fetchAlbum(id: UUID) throws -> Album? {
        var descriptor = FetchDescriptor<Album>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func listAlbums() throws -> [Album] {
        var descriptor = FetchDescriptor<Album>()
        descriptor.sortBy = [SortDescriptor(\.title)]
        return try modelContext.fetch(descriptor)
    }
}
