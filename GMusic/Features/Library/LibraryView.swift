import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable {
    case tracks = "Tracks"
    case albums = "Albums"
    case artists = "Artists"
    case playlists = "Playlists"
    var id: String { rawValue }
}

struct LibraryView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var playerService: PlayerService
    @StateObject private var viewModel: LibraryViewModel
    @State private var section: LibrarySection = .tracks
    @State private var isCreatingPlaylist = false
    @State private var newPlaylistTitle = ""
    @State private var editingTrack: Track?

    init(appEnvironment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: LibraryViewModel(
            trackRepository: appEnvironment.trackRepository,
            albumRepository: appEnvironment.albumRepository,
            playlistRepository: appEnvironment.playlistRepository,
            librarySnapshotStore: appEnvironment.librarySnapshotStore
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(LibrarySection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                content
            }
            .navigationTitle("Library")
            .toolbar {
                if section == .tracks {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Title") { Task { await viewModel.changeSort(.titleAscending) } }
                            Button("Artist") { Task { await viewModel.changeSort(.artistAscending) } }
                            Button("Recently Imported") { Task { await viewModel.changeSort(.recentlyImported) } }
                            Button("Most Played") { Task { await viewModel.changeSort(.mostPlayed) } }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                        }
                    }
                }
                if section == .playlists {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isCreatingPlaylist = true } label: { Image(systemName: "plus") }
                    }
                }
                if section == .artists {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Normalize Case") {
                            Task { await viewModel.normalizeArtistsByCase() }
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: searchPrompt)
            .sheet(item: $editingTrack) { track in
                TrackEditorView(appEnvironment: appEnvironment, track: track) {
                    Task { await viewModel.loadAll() }
                }
            }
            .alert("Create Playlist", isPresented: $isCreatingPlaylist) {
                TextField("Playlist name", text: $newPlaylistTitle)
                Button("Cancel", role: .cancel) { newPlaylistTitle = "" }
                Button("Create") {
                    Task {
                        await viewModel.createPlaylist(title: newPlaylistTitle)
                        newPlaylistTitle = ""
                    }
                }
            }
        }
        .task { await viewModel.bootstrap() }
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .tracks:
            trackList
        case .albums:
            albumList
        case .artists:
            artistList
        case .playlists:
            playlistList
        }
    }

    private var searchPrompt: String {
        switch section {
        case .tracks: "Search tracks"
        case .albums: "Search albums"
        case .artists: "Search artists"
        case .playlists: "Search playlists"
        }
    }

    private var trackList: some View {
        List {
            ForEach(viewModel.filteredTracks) { track in
                TrackRowView(
                    track: track,
                    artworkURL: track.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) },
                    isCurrent: playerService.currentTrack?.id == track.id,
                    isPlaying: playerService.isPlaying && playerService.currentTrack?.id == track.id
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Task { await playerService.playQueue(trackIDs: viewModel.filteredTracks.map(\.id), startAt: viewModel.filteredTracks.firstIndex(where: { $0.id == track.id }) ?? 0) }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        Task { await viewModel.toggleFavorite(track) }
                    } label: {
                        Label("Favorite", systemImage: track.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteTrack(track, fileStorage: appEnvironment.fileStorage) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editingTrack = track
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Menu("Add to Playlist") {
                        ForEach(viewModel.playlists) { playlist in
                            Button(playlist.title) {
                                Task { await viewModel.addTrack(track.id, toPlaylist: playlist.id) }
                            }
                        }
                    }
                    Button {
                        editingTrack = track
                    } label: {
                        Label("Edit Metadata", systemImage: "pencil")
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.filteredTracks.isEmpty {
                ContentUnavailableView("No Tracks", systemImage: "music.note", description: Text("Import audio files to get started."))
            }
        }
    }

    private var albumList: some View {
        List(viewModel.filteredAlbums) { album in
            NavigationLink {
                AlbumDetailView(appEnvironment: appEnvironment, album: album, libraryViewModel: viewModel)
            } label: {
                HStack {
                    ArtworkView(imageURL: album.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) })
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading) {
                        Text(album.title).font(.body)
                        Text(album.artistName).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.filteredAlbums.isEmpty {
                ContentUnavailableView("No Albums", systemImage: "square.stack")
            }
        }
    }

    private var playlistList: some View {
        List {
            ForEach(viewModel.filteredPlaylists) { playlist in
                NavigationLink {
                    PlaylistDetailView(appEnvironment: appEnvironment, playlist: playlist, libraryViewModel: viewModel)
                } label: {
                    HStack {
                        ArtworkView(imageURL: playlist.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) })
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading) {
                            Text(playlist.title).font(.body)
                            Text("\(playlist.trackIDs.count) tracks").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    let playlist = viewModel.filteredPlaylists[index]
                    Task { await viewModel.deletePlaylist(playlist) }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.filteredPlaylists.isEmpty {
                ContentUnavailableView("No Playlists", systemImage: "music.note.list")
            }
        }
    }

    private var artistList: some View {
        List(viewModel.filteredArtists) { artist in
            NavigationLink {
                ArtistPlaylistDetailView(appEnvironment: appEnvironment, artist: artist, libraryViewModel: viewModel)
            } label: {
                HStack(spacing: 12) {
                    ArtworkView(imageURL: artist.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) })
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(artist.displayName).font(.body)
                        Text("Artist Playlist • \(artist.trackCount) tracks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if artist.alternateNames.count > 1 {
                        Spacer()
                        Text("\(artist.alternateNames.count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppColors.secondaryBackground))
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.filteredArtists.isEmpty {
                ContentUnavailableView("No Artists", systemImage: "music.mic")
            }
        }
    }
}
