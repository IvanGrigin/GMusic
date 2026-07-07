import SwiftUI
import PhotosUI

struct AlbumDetailView: View {
    let appEnvironment: AppEnvironment
    let album: Album
    @ObservedObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var playerService: PlayerService

    @State private var tracks: [Track] = []
    @State private var displayTitle: String
    @State private var displayArtist: String
    @State private var displayGenre: String
    @State private var displayYear: Int?
    @State private var displayArtworkID: UUID?
    @State private var isShowingEditor = false

    init(appEnvironment: AppEnvironment, album: Album, libraryViewModel: LibraryViewModel) {
        self.appEnvironment = appEnvironment
        self.album = album
        self.libraryViewModel = libraryViewModel
        _displayTitle = State(initialValue: album.title)
        _displayArtist = State(initialValue: album.artistName)
        _displayGenre = State(initialValue: album.genre ?? "")
        _displayYear = State(initialValue: album.year)
        _displayArtworkID = State(initialValue: album.artworkID)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    ArtworkView(imageURL: displayArtworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) })
                        .frame(width: 160, height: 160)
                    Spacer()
                }
                .listRowSeparator(.hidden)

                VStack(spacing: 4) {
                    Text(displayArtist)
                        .font(.headline)
                    if !displayGenre.isEmpty || displayYear != nil {
                        Text([displayGenre.trimmedNonEmpty, displayYear.map(String.init)].compactMap { $0 }.joined(separator: " • "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Button {
                    Task { await playerService.playQueue(trackIDs: tracks.map(\.id), startAt: 0) }
                } label: {
                    Label("Play Album", systemImage: "play.fill")
                }
                .disabled(tracks.isEmpty)
            }

            Section("Tracks") {
                ForEach(tracks) { track in
                    TrackRowView(
                        track: track,
                        artworkURL: track.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) },
                        isCurrent: playerService.currentTrack?.id == track.id,
                        isPlaying: playerService.isPlaying && playerService.currentTrack?.id == track.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task {
                            await playerService.playQueue(
                                trackIDs: tracks.map(\.id),
                                startAt: tracks.firstIndex(where: { $0.id == track.id }) ?? 0
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(displayTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            AlbumEditorSheet(
                appEnvironment: appEnvironment,
                initialTitle: displayTitle,
                initialArtist: displayArtist,
                initialGenre: displayGenre,
                initialYear: displayYear,
                initialArtworkID: displayArtworkID
            ) { title, artist, year, genre, artworkID in
                Task {
                    await libraryViewModel.updateAlbum(
                        album.id,
                        title: title,
                        artistName: artist,
                        year: year,
                        genre: genre,
                        artworkID: artworkID
                    )
                    await refreshAlbumDetails()
                }
            }
        }
        .task { await refreshAlbumDetails() }
    }

    private func refreshAlbumDetails() async {
        tracks = await libraryViewModel.tracksForAlbum(album.id)
        if let refreshed = try? await appEnvironment.albumRepository.fetchAlbum(id: album.id) {
            displayTitle = refreshed.title
            displayArtist = refreshed.artistName
            displayGenre = refreshed.genre ?? ""
            displayYear = refreshed.year
            displayArtworkID = refreshed.artworkID
        }
    }
}

private struct AlbumEditorSheet: View {
    let appEnvironment: AppEnvironment
    let initialTitle: String
    let initialArtist: String
    let initialGenre: String
    let initialYear: Int?
    let initialArtworkID: UUID?
    let onSave: (String, String, Int?, String, UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var artist: String
    @State private var genre: String
    @State private var yearText: String
    @State private var artworkID: UUID?
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingArtwork: ArtworkDraft?

    init(
        appEnvironment: AppEnvironment,
        initialTitle: String,
        initialArtist: String,
        initialGenre: String,
        initialYear: Int?,
        initialArtworkID: UUID?,
        onSave: @escaping (String, String, Int?, String, UUID?) -> Void
    ) {
        self.appEnvironment = appEnvironment
        self.initialTitle = initialTitle
        self.initialArtist = initialArtist
        self.initialGenre = initialGenre
        self.initialYear = initialYear
        self.initialArtworkID = initialArtworkID
        self.onSave = onSave
        _title = State(initialValue: initialTitle)
        _artist = State(initialValue: initialArtist)
        _genre = State(initialValue: initialGenre)
        _yearText = State(initialValue: initialYear.map(String.init) ?? "")
        _artworkID = State(initialValue: initialArtworkID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ArtworkView(imageURL: artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) })
                            .frame(width: 140, height: 140)
                        Spacer()
                    }

                    PhotosPicker("Choose Artwork", selection: $photoItem, matching: .images)

                    if artworkID != nil {
                        Button("Remove Artwork", role: .destructive) {
                            artworkID = nil
                        }
                    }
                }

                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Artist", text: $artist)
                    TextField("Genre", text: $genre)
                    TextField("Year", text: $yearText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit Album")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, artist, Int(yearText), genre, artworkID)
                        dismiss()
                    }
                    .disabled(title.trimmedNonEmpty == nil || artist.trimmedNonEmpty == nil)
                }
            }
            .onChange(of: photoItem) { _, newValue in
                Task {
                    if let newValue,
                       let data = try? await newValue.loadTransferable(type: Data.self) {
                        pendingArtwork = ArtworkDraft(imageData: data)
                    }
                    photoItem = nil
                }
            }
            .sheet(item: $pendingArtwork) { draft in
                SquareArtworkEditorSheet(imageData: draft.imageData) { renderedData in
                    let newArtworkID = UUID()
                    if (try? appEnvironment.artworkFileStore.save(imageData: renderedData, artworkID: newArtworkID)) != nil {
                        artworkID = newArtworkID
                    }
                }
            }
        }
    }
}
