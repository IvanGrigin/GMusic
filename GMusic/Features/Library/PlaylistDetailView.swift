import SwiftUI
import PhotosUI

struct PlaylistDetailView: View {
    let appEnvironment: AppEnvironment
    let playlist: Playlist
    @ObservedObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var playerService: PlayerService

    @State private var tracks: [Track] = []
    @State private var displayTitle: String
    @State private var displaySubtitle: String
    @State private var displayArtworkID: UUID?
    @State private var isShowingTrackPicker = false
    @State private var isShowingEditor = false

    init(appEnvironment: AppEnvironment, playlist: Playlist, libraryViewModel: LibraryViewModel) {
        self.appEnvironment = appEnvironment
        self.playlist = playlist
        self.libraryViewModel = libraryViewModel
        _displayTitle = State(initialValue: playlist.title)
        _displaySubtitle = State(initialValue: playlist.subtitle ?? "")
        _displayArtworkID = State(initialValue: playlist.artworkID)
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

                if !displaySubtitle.isEmpty {
                    Text(displaySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await playerService.playQueue(trackIDs: tracks.map(\.id), startAt: 0) }
                } label: {
                    Label("Play Playlist", systemImage: "play.fill")
                }
                .disabled(tracks.isEmpty)

                Button {
                    isShowingTrackPicker = true
                } label: {
                    Label("Add Tracks", systemImage: "plus.circle")
                }
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
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                await libraryViewModel.removeTrack(track.id, fromPlaylist: playlist.id)
                                await refreshPlaylistDetails()
                            }
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                    }
                }
                .onMove { source, destination in
                    tracks.move(fromOffsets: source, toOffset: destination)
                    Task {
                        await libraryViewModel.reorderPlaylist(playlist, newOrder: tracks.map(\.id))
                        await refreshPlaylistDetails()
                    }
                }
            }
        }
        .navigationTitle(displayTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingTrackPicker = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $isShowingTrackPicker) {
            PlaylistTrackPickerSheet(
                appEnvironment: appEnvironment,
                libraryViewModel: libraryViewModel,
                playlistTitle: displayTitle,
                selectedTrackIDs: Set(tracks.map(\.id))
            ) { trackID in
                Task {
                    await libraryViewModel.addTrack(trackID, toPlaylist: playlist.id)
                    await refreshPlaylistDetails()
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            PlaylistEditorSheet(
                appEnvironment: appEnvironment,
                initialTitle: displayTitle,
                initialSubtitle: displaySubtitle,
                initialArtworkID: displayArtworkID
            ) { title, subtitle, artworkID in
                Task {
                    await libraryViewModel.updatePlaylist(
                        playlist.id,
                        title: title,
                        subtitle: subtitle,
                        artworkID: artworkID
                    )
                    await refreshPlaylistDetails()
                }
            }
        }
        .overlay {
            if tracks.isEmpty {
                ContentUnavailableView(
                    "No Tracks",
                    systemImage: "music.note.list",
                    description: Text("Use Add Tracks to put music into this playlist.")
                )
            }
        }
        .task { await refreshPlaylistDetails() }
    }

    private func refreshPlaylistDetails() async {
        tracks = await libraryViewModel.tracksForPlaylist(playlist)
        if let refreshed = try? await appEnvironment.playlistRepository.fetchPlaylist(id: playlist.id) {
            displayTitle = refreshed.title
            displaySubtitle = refreshed.subtitle ?? ""
            displayArtworkID = refreshed.artworkID
        }
    }
}

private struct PlaylistTrackPickerSheet: View {
    let appEnvironment: AppEnvironment
    @ObservedObject var libraryViewModel: LibraryViewModel
    let playlistTitle: String
    let selectedTrackIDs: Set<UUID>
    let onAddTrack: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredTracks: [Track] {
        let tracks = libraryViewModel.tracks
        guard let query = searchText.trimmedNonEmpty else { return tracks }
        let needle = query.normalizedForSearch
        return tracks.filter {
            $0.title.normalizedForSearch.contains(needle) ||
            $0.artistName.normalizedForSearch.contains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredTracks) { track in
                HStack(spacing: 12) {
                    ArtworkView(imageURL: track.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) })
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                        Text(track.artistName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        onAddTrack(track.id)
                    } label: {
                        Image(systemName: selectedTrackIDs.contains(track.id) ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedTrackIDs.contains(track.id))
                }
            }
            .navigationTitle("Add to \(playlistTitle)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search tracks")
            .task {
                if libraryViewModel.tracks.isEmpty {
                    await libraryViewModel.loadAll()
                }
            }
        }
    }
}

private struct PlaylistEditorSheet: View {
    let appEnvironment: AppEnvironment
    let initialTitle: String
    let initialSubtitle: String
    let initialArtworkID: UUID?
    let onSave: (String, String, UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var subtitle: String
    @State private var artworkID: UUID?
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingArtwork: ArtworkDraft?

    init(
        appEnvironment: AppEnvironment,
        initialTitle: String,
        initialSubtitle: String,
        initialArtworkID: UUID?,
        onSave: @escaping (String, String, UUID?) -> Void
    ) {
        self.appEnvironment = appEnvironment
        self.initialTitle = initialTitle
        self.initialSubtitle = initialSubtitle
        self.initialArtworkID = initialArtworkID
        self.onSave = onSave
        _title = State(initialValue: initialTitle)
        _subtitle = State(initialValue: initialSubtitle)
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
                    TextField("Subtitle", text: $subtitle)
                }
            }
            .navigationTitle("Edit Playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, subtitle, artworkID)
                        dismiss()
                    }
                    .disabled(title.trimmedNonEmpty == nil)
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
