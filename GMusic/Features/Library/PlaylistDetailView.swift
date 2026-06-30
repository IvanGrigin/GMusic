import SwiftUI

struct PlaylistDetailView: View {
    let appEnvironment: AppEnvironment
    let playlist: Playlist
    @ObservedObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var playerService: PlayerService
    @State private var tracks: [Track] = []

    var body: some View {
        List {
            Button {
                Task { await playerService.playQueue(trackIDs: tracks.map(\.id), startAt: 0) }
            } label: {
                Label("Play Playlist", systemImage: "play.fill")
            }
            .disabled(tracks.isEmpty)

            ForEach(tracks) { track in
                TrackRowView(
                    track: track,
                    artworkURL: track.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) },
                    isCurrent: playerService.currentTrack?.id == track.id,
                    isPlaying: playerService.isPlaying && playerService.currentTrack?.id == track.id
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Task { await playerService.playQueue(trackIDs: tracks.map(\.id), startAt: tracks.firstIndex(where: { $0.id == track.id }) ?? 0) }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task {
                            await libraryViewModel.removeTrack(track.id, fromPlaylist: playlist.id)
                            tracks = await libraryViewModel.tracksForPlaylist(playlist)
                        }
                    } label: {
                        Label("Remove", systemImage: "minus.circle")
                    }
                }
            }
            .onMove { source, destination in
                tracks.move(fromOffsets: source, toOffset: destination)
                Task { await libraryViewModel.reorderPlaylist(playlist, newOrder: tracks.map(\.id)) }
            }
        }
        .navigationTitle(playlist.title)
        .toolbar { EditButton() }
        .overlay {
            if tracks.isEmpty {
                ContentUnavailableView("No Tracks", systemImage: "music.note.list", description: Text("Add tracks to this playlist from the Tracks tab."))
            }
        }
        .task { tracks = await libraryViewModel.tracksForPlaylist(playlist) }
    }
}
