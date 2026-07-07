import SwiftUI

struct ArtistPlaylistDetailView: View {
    let appEnvironment: AppEnvironment
    let artist: ArtistSummary
    @ObservedObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var playerService: PlayerService

    @State private var tracks: [Track] = []
    @State private var currentArtist: ArtistSummary
    @State private var mergeSuggestions: [ArtistMergeSuggestion] = []

    init(appEnvironment: AppEnvironment, artist: ArtistSummary, libraryViewModel: LibraryViewModel) {
        self.appEnvironment = appEnvironment
        self.artist = artist
        self.libraryViewModel = libraryViewModel
        _currentArtist = State(initialValue: artist)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    ArtworkView(imageURL: currentArtist.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) })
                        .frame(width: 160, height: 160)
                    Spacer()
                }
                .listRowSeparator(.hidden)

                VStack(spacing: 4) {
                    Text("Artist Playlist")
                        .font(.headline)
                    Text("\(currentArtist.trackCount) tracks")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Button {
                    Task { await playerService.playQueue(trackIDs: currentArtist.trackIDs, startAt: 0) }
                } label: {
                    Label("Play Artist", systemImage: "play.fill")
                }
                .disabled(currentArtist.trackIDs.isEmpty)
            }

            if currentArtist.alternateNames.count > 1 {
                Section("Known Spellings") {
                    ForEach(currentArtist.alternateNames, id: \.self) { name in
                        Text(name)
                    }
                }
            }

            if !mergeSuggestions.isEmpty {
                Section("Similar Artists") {
                    ForEach(mergeSuggestions) { suggestion in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.source.displayName)
                                Text("Distance: \(suggestion.distance) • \(suggestion.source.trackCount) tracks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Merge") {
                                Task {
                                    await libraryViewModel.mergeArtists(
                                        sourceNames: suggestion.source.alternateNames,
                                        into: currentArtist.displayName
                                    )
                                    await refresh()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
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
                                trackIDs: currentArtist.trackIDs,
                                startAt: currentArtist.trackIDs.firstIndex(of: track.id) ?? 0
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(currentArtist.displayName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Normalize Case") {
                    Task {
                        await libraryViewModel.normalizeArtistsByCase()
                        await refresh()
                    }
                }
            }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        if let refreshedArtist = libraryViewModel.artistSummary(for: currentArtist.id) ?? libraryViewModel.artistSummary(for: artist.id) {
            currentArtist = refreshedArtist
        }
        tracks = await libraryViewModel.tracksForArtist(currentArtist)
        mergeSuggestions = await libraryViewModel.mergeSuggestions(for: currentArtist)
    }
}
