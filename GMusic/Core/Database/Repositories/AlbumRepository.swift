import Foundation
import SwiftData

@ModelActor
actor AlbumRepository {
    func findOrCreateAlbum(title: String, artistName: String) throws -> UUID {
        let allAlbums = try modelContext.fetch(FetchDescriptor<Album>())
        if let existing = allAlbums.first(where: {
            $0.title.normalizedArtistComparison == title.normalizedArtistComparison &&
            $0.artistName.normalizedArtistKey == artistName.normalizedArtistKey
        }) {
            if existing.artistName != artistName, existing.artistName.normalizedArtistKey == artistName.normalizedArtistKey {
                existing.artistName = preferredArtistName(existing.artistName, artistName)
                existing.updatedAt = .now
                try modelContext.save()
            }
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

    private func preferredArtistName(_ left: String, _ right: String) -> String {
        let candidates = [left, right]
        return candidates.sorted { lhs, rhs in
            let lhsIsLower = lhs == lhs.lowercased()
            let rhsIsLower = rhs == rhs.lowercased()
            if lhsIsLower != rhsIsLower {
                return !lhsIsLower
            }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.first ?? left
    }
}
