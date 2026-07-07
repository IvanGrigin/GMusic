import Foundation

@MainActor
final class TrackEditorViewModel: ObservableObject {
    @Published var title: String
    @Published var artistName: String
    @Published var albumTitle: String
    @Published var genre: String
    @Published var yearText: String
    @Published var trackNumberText: String
    @Published var lyrics: String
    @Published var artworkID: UUID?
    @Published var errorMessage: String?
    @Published var isSaving = false

    let track: Track
    private let trackRepository: TrackRepository
    private let albumRepository: AlbumRepository
    private let artworkFileStore: ArtworkFileStore

    init(track: Track, trackRepository: TrackRepository, albumRepository: AlbumRepository, artworkFileStore: ArtworkFileStore) {
        self.track = track
        self.trackRepository = trackRepository
        self.albumRepository = albumRepository
        self.artworkFileStore = artworkFileStore
        title = track.title
        artistName = track.artistName
        albumTitle = ""
        genre = track.genre ?? ""
        yearText = track.year.map(String.init) ?? ""
        trackNumberText = track.trackNumber.map(String.init) ?? ""
        lyrics = track.lyrics ?? ""
        artworkID = track.artworkID
        if let albumID = track.albumID {
            Task { [weak self] in
                if let album = try? await albumRepository.fetchAlbum(id: albumID) {
                    self?.albumTitle = album.title
                }
            }
        }
    }

    func setArtwork(imageData: Data) {
        let newID = UUID()
        guard (try? artworkFileStore.save(imageData: imageData, artworkID: newID)) != nil else { return }
        artworkID = newID
    }

    func removeArtwork() {
        artworkID = nil
    }

    func save() async -> Bool {
        guard let validTitle = title.trimmedNonEmpty, let validArtist = artistName.trimmedNonEmpty else {
            errorMessage = "Title and artist are required."
            return false
        }
        isSaving = true
        defer { isSaving = false }

        var newAlbumID: UUID?
        if let albumTitleTrimmed = albumTitle.trimmedNonEmpty {
            newAlbumID = try? await albumRepository.findOrCreateAlbum(title: albumTitleTrimmed, artistName: validArtist)
        }

        let yearValue = Int(yearText)
        let trackNumberValue = Int(trackNumberText)
        let genreValue = genre.trimmedNonEmpty
        let lyricsValue = lyrics.trimmedNonEmpty
        let artworkIDValue = artworkID

        do {
            try await trackRepository.updateTrack(id: track.id) { t in
                t.title = validTitle
                t.artistName = validArtist
                t.albumID = newAlbumID
                t.genre = genreValue
                t.year = yearValue
                t.trackNumber = trackNumberValue
                t.lyrics = lyricsValue
                t.artworkID = artworkIDValue
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
