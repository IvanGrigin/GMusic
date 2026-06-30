import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var albums: [Album] = []
    @Published var playlists: [Playlist] = []
    @Published var searchText: String = ""
    @Published var sortOption: TrackSortOption = .titleAscending
    @Published var errorMessage: String?

    private let trackRepository: TrackRepository
    private let albumRepository: AlbumRepository
    private let playlistRepository: PlaylistRepository

    init(trackRepository: TrackRepository, albumRepository: AlbumRepository, playlistRepository: PlaylistRepository) {
        self.trackRepository = trackRepository
        self.albumRepository = albumRepository
        self.playlistRepository = playlistRepository
    }

    var filteredTracks: [Track] {
        guard let query = searchText.trimmedNonEmpty else { return tracks }
        let needle = query.normalizedForSearch
        return tracks.filter {
            $0.title.normalizedForSearch.contains(needle) || $0.artistName.normalizedForSearch.contains(needle)
        }
    }

    func loadAll() async {
        do {
            tracks = try await trackRepository.listTracks(sortedBy: sortOption)
            albums = try await albumRepository.listAlbums()
            playlists = try await playlistRepository.listPlaylists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changeSort(_ option: TrackSortOption) async {
        sortOption = option
        await loadAll()
    }

    func toggleFavorite(_ track: Track) async {
        do {
            try await trackRepository.updateTrack(id: track.id) { $0.isFavorite.toggle() }
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTrack(_ track: Track, fileStorage: FileStorage) async {
        do {
            try await trackRepository.deleteTrack(id: track.id)
            try? fileStorage.deleteAudio(relativePath: track.fileRelativePath)
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func tracksForAlbum(_ albumID: UUID) async -> [Track] {
        (try? await trackRepository.listTracks(albumID: albumID)) ?? []
    }

    func tracksForPlaylist(_ playlist: Playlist) async -> [Track] {
        (try? await trackRepository.listTracks(ids: playlist.trackIDs)) ?? []
    }

    func createPlaylist(title: String) async {
        guard let title = title.trimmedNonEmpty else { return }
        do {
            try await playlistRepository.createPlaylist(Playlist(title: title))
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePlaylist(_ playlist: Playlist) async {
        do {
            try await playlistRepository.deletePlaylist(id: playlist.id)
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addTrack(_ trackID: UUID, toPlaylist playlistID: UUID) async {
        try? await playlistRepository.addTrack(trackID, toPlaylist: playlistID)
        await loadAll()
    }

    func removeTrack(_ trackID: UUID, fromPlaylist playlistID: UUID) async {
        try? await playlistRepository.removeTrack(trackID, fromPlaylist: playlistID)
        await loadAll()
    }

    func reorderPlaylist(_ playlist: Playlist, newOrder: [UUID]) async {
        try? await playlistRepository.reorderTracks(in: playlist.id, to: newOrder)
        await loadAll()
    }
}
