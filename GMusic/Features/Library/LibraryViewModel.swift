import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var albums: [Album] = []
    @Published var playlists: [Playlist] = []
    @Published var artists: [ArtistSummary] = []
    @Published var searchText: String = ""
    @Published var sortOption: TrackSortOption = .titleAscending
    @Published var errorMessage: String?

    private let trackRepository: TrackRepository
    private let albumRepository: AlbumRepository
    private let playlistRepository: PlaylistRepository
    private let librarySnapshotStore: LibrarySnapshotStore
    private var hasNormalizedArtistsThisSession = false
    private var hasBootstrapped = false

    init(
        trackRepository: TrackRepository,
        albumRepository: AlbumRepository,
        playlistRepository: PlaylistRepository,
        librarySnapshotStore: LibrarySnapshotStore
    ) {
        self.trackRepository = trackRepository
        self.albumRepository = albumRepository
        self.playlistRepository = playlistRepository
        self.librarySnapshotStore = librarySnapshotStore
    }

    var filteredTracks: [Track] {
        guard let query = searchText.trimmedNonEmpty else { return tracks }
        let needle = query.normalizedForSearch
        return tracks.filter {
            $0.title.normalizedForSearch.contains(needle) || $0.artistName.normalizedForSearch.contains(needle)
        }
    }

    var filteredAlbums: [Album] {
        guard let query = searchText.trimmedNonEmpty else { return albums }
        let needle = query.normalizedForSearch
        return albums.filter {
            $0.title.normalizedForSearch.contains(needle) || $0.artistName.normalizedForSearch.contains(needle)
        }
    }

    var filteredArtists: [ArtistSummary] {
        guard let query = searchText.trimmedNonEmpty else { return artists }
        let needle = query.normalizedForSearch
        return artists.filter {
            $0.displayName.normalizedForSearch.contains(needle) ||
            $0.alternateNames.contains(where: { $0.normalizedForSearch.contains(needle) })
        }
    }

    var filteredPlaylists: [Playlist] {
        guard let query = searchText.trimmedNonEmpty else { return playlists }
        let needle = query.normalizedForSearch
        return playlists.filter {
            $0.title.normalizedForSearch.contains(needle) ||
            ($0.subtitle?.normalizedForSearch.contains(needle) ?? false)
        }
    }

    func bootstrap() async {
        guard !hasBootstrapped else {
            await loadAll()
            return
        }

        hasBootstrapped = true
        if let snapshot = await librarySnapshotStore.loadSnapshot() {
            apply(snapshot: snapshot)
        }
        await loadAll()
    }

    func loadAll() async {
        do {
            if !hasNormalizedArtistsThisSession {
                _ = try await trackRepository.normalizeArtistCapitalizationVariants()
                hasNormalizedArtistsThisSession = true
            }

            async let tracksTask = trackRepository.listTracks(sortedBy: sortOption)
            async let albumsTask = albumRepository.listAlbums()
            async let playlistsTask = playlistRepository.listPlaylists()
            async let artistsTask = trackRepository.listArtistSummaries()

            tracks = try await tracksTask
            albums = try await albumsTask
            playlists = try await playlistsTask
            artists = try await artistsTask
            _ = await librarySnapshotStore.refreshSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changeSort(_ option: TrackSortOption) async {
        sortOption = option
        await loadAll()
    }

    func normalizeArtistsByCase() async {
        do {
            _ = try await trackRepository.normalizeArtistCapitalizationVariants()
            hasNormalizedArtistsThisSession = true
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
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

    func artistSummary(for id: String) -> ArtistSummary? {
        artists.first(where: { $0.id == id })
    }

    func tracksForArtist(_ artist: ArtistSummary) async -> [Track] {
        (try? await trackRepository.listTracks(ids: artist.trackIDs)) ?? []
    }

    func mergeSuggestions(for artist: ArtistSummary) async -> [ArtistMergeSuggestion] {
        (try? await trackRepository.listMergeSuggestions(for: artist.normalizedKey)) ?? []
    }

    func mergeArtists(sourceNames: [String], into targetName: String) async {
        do {
            _ = try await trackRepository.mergeArtists(sourceNames: sourceNames, into: targetName)
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
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

    func updatePlaylist(
        _ playlistID: UUID,
        title: String,
        subtitle: String?,
        artworkID: UUID?
    ) async {
        guard let trimmedTitle = title.trimmedNonEmpty else { return }
        do {
            try await playlistRepository.updatePlaylist(id: playlistID) { playlist in
                playlist.title = trimmedTitle
                playlist.subtitle = subtitle?.trimmedNonEmpty
                playlist.artworkID = artworkID
            }
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateAlbum(
        _ albumID: UUID,
        title: String,
        artistName: String,
        year: Int?,
        genre: String?,
        artworkID: UUID?
    ) async {
        guard let trimmedTitle = title.trimmedNonEmpty,
              let trimmedArtist = artistName.trimmedNonEmpty else { return }
        do {
            try await albumRepository.updateAlbum(id: albumID) { album in
                album.title = trimmedTitle
                album.artistName = trimmedArtist
                album.year = year
                album.genre = genre?.trimmedNonEmpty
                album.artworkID = artworkID
            }
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(snapshot: LibrarySnapshotStore.SnapshotPayload) {
        tracks = snapshot.tracks.map { $0.makeTrack() }
        albums = snapshot.albums.map { $0.makeAlbum() }
        playlists = snapshot.playlists.map { $0.makePlaylist() }
        artists = snapshot.artists
    }
}
