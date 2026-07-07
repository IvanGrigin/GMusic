import Foundation

actor LibrarySnapshotStore {
    struct SnapshotPayload: Codable {
        let generatedAt: Date
        let tracks: [CachedTrack]
        let albums: [CachedAlbum]
        let playlists: [CachedPlaylist]
        let artists: [ArtistSummary]
    }

    struct CachedTrack: Codable {
        let id: UUID
        let fileRelativePath: String
        let originalSourcePath: String?
        let originalFileName: String
        let fileHashSHA256: String
        let fileSizeBytes: Int64
        let title: String
        let sortTitle: String?
        let originalTitle: String?
        let alternateTitles: [String]
        let artistName: String
        let albumArtistName: String?
        let albumID: UUID?
        let discNumber: Int?
        let trackNumber: Int?
        let genre: String?
        let year: Int?
        let durationSeconds: Double
        let bitrate: Int?
        let sampleRate: Int?
        let artworkID: UUID?
        let lyrics: String?
        let userTags: [String]
        let dateImported: Date
        let lastPlayedAt: Date?
        let playCount: Int
        let isFavorite: Bool
        let userRating: Int?

        init(track: Track) {
            id = track.id
            fileRelativePath = track.fileRelativePath
            originalSourcePath = track.originalSourcePath
            originalFileName = track.originalFileName
            fileHashSHA256 = track.fileHashSHA256
            fileSizeBytes = track.fileSizeBytes
            title = track.title
            sortTitle = track.sortTitle
            originalTitle = track.originalTitle
            alternateTitles = track.alternateTitles
            artistName = track.artistName
            albumArtistName = track.albumArtistName
            albumID = track.albumID
            discNumber = track.discNumber
            trackNumber = track.trackNumber
            genre = track.genre
            year = track.year
            durationSeconds = track.durationSeconds
            bitrate = track.bitrate
            sampleRate = track.sampleRate
            artworkID = track.artworkID
            lyrics = track.lyrics
            userTags = track.userTags
            dateImported = track.dateImported
            lastPlayedAt = track.lastPlayedAt
            playCount = track.playCount
            isFavorite = track.isFavorite
            userRating = track.userRating
        }

        func makeTrack() -> Track {
            Track(
                id: id,
                fileRelativePath: fileRelativePath,
                originalSourcePath: originalSourcePath,
                originalFileName: originalFileName,
                fileHashSHA256: fileHashSHA256,
                fileSizeBytes: fileSizeBytes,
                title: title,
                sortTitle: sortTitle,
                originalTitle: originalTitle,
                alternateTitles: alternateTitles,
                artistName: artistName,
                albumArtistName: albumArtistName,
                albumID: albumID,
                discNumber: discNumber,
                trackNumber: trackNumber,
                genre: genre,
                year: year,
                durationSeconds: durationSeconds,
                bitrate: bitrate,
                sampleRate: sampleRate,
                artworkID: artworkID,
                lyrics: lyrics,
                userTags: userTags,
                dateImported: dateImported,
                lastPlayedAt: lastPlayedAt,
                playCount: playCount,
                isFavorite: isFavorite,
                userRating: userRating
            )
        }
    }

    struct CachedAlbum: Codable {
        let id: UUID
        let title: String
        let sortTitle: String?
        let originalTitle: String?
        let alternateTitles: [String]
        let artistName: String
        let year: Int?
        let genre: String?
        let artworkID: UUID?
        let createdAt: Date
        let updatedAt: Date

        init(album: Album) {
            id = album.id
            title = album.title
            sortTitle = album.sortTitle
            originalTitle = album.originalTitle
            alternateTitles = album.alternateTitles
            artistName = album.artistName
            year = album.year
            genre = album.genre
            artworkID = album.artworkID
            createdAt = album.createdAt
            updatedAt = album.updatedAt
        }

        func makeAlbum() -> Album {
            Album(
                id: id,
                title: title,
                sortTitle: sortTitle,
                originalTitle: originalTitle,
                alternateTitles: alternateTitles,
                artistName: artistName,
                year: year,
                genre: genre,
                artworkID: artworkID,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    struct CachedPlaylist: Codable {
        let id: UUID
        let title: String
        let subtitle: String?
        let alternateTitles: [String]
        let artworkID: UUID?
        let trackIDs: [UUID]
        let createdAt: Date
        let updatedAt: Date

        init(playlist: Playlist) {
            id = playlist.id
            title = playlist.title
            subtitle = playlist.subtitle
            alternateTitles = playlist.alternateTitles
            artworkID = playlist.artworkID
            trackIDs = playlist.trackIDs
            createdAt = playlist.createdAt
            updatedAt = playlist.updatedAt
        }

        func makePlaylist() -> Playlist {
            Playlist(
                id: id,
                title: title,
                subtitle: subtitle,
                alternateTitles: alternateTitles,
                artworkID: artworkID,
                trackIDs: trackIDs,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    private let snapshotURL: URL
    private let trackRepository: TrackRepository
    private let albumRepository: AlbumRepository
    private let playlistRepository: PlaylistRepository
    private let widgetSharedStore = WidgetSharedStore()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        storagePaths: StoragePaths,
        trackRepository: TrackRepository,
        albumRepository: AlbumRepository,
        playlistRepository: PlaylistRepository
    ) {
        snapshotURL = storagePaths.cacheDirectory.appendingPathComponent("library-snapshot.json")
        self.trackRepository = trackRepository
        self.albumRepository = albumRepository
        self.playlistRepository = playlistRepository
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadSnapshot() -> SnapshotPayload? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? decoder.decode(SnapshotPayload.self, from: data)
    }

    @discardableResult
    func refreshSnapshot() async -> SnapshotPayload? {
        do {
            _ = try await trackRepository.normalizeArtistCapitalizationVariants()
            async let tracksTask = trackRepository.listTracks(sortedBy: .titleAscending)
            async let albumsTask = albumRepository.listAlbums()
            async let playlistsTask = playlistRepository.listPlaylists()
            async let artistsTask = trackRepository.listArtistSummaries()

            let payload = SnapshotPayload(
                generatedAt: .now,
                tracks: (try await tracksTask).map(CachedTrack.init),
                albums: (try await albumsTask).map(CachedAlbum.init),
                playlists: (try await playlistsTask).map(CachedPlaylist.init),
                artists: try await artistsTask
            )

            let data = try encoder.encode(payload)
            try data.write(to: snapshotURL, options: .atomic)
            widgetSharedStore.saveLibrarySnapshot(
                LibraryWidgetSnapshot(
                    trackCount: payload.tracks.count,
                    albumCount: payload.albums.count,
                    playlistCount: payload.playlists.count,
                    artistCount: payload.artists.count,
                    latestTrackTitle: payload.tracks.first?.title,
                    latestArtistName: payload.tracks.first?.artistName,
                    updatedAt: payload.generatedAt
                )
            )
            return payload
        } catch {
            return nil
        }
    }
}
