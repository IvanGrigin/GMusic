import SwiftUI

struct AlbumDetailView: View {
    let appEnvironment: AppEnvironment
    let album: Album
    @ObservedObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var playerService: PlayerService
    @State private var tracks: [Track] = []

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    ArtworkView(imageURL: album.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) })
                        .frame(width: 160, height: 160)
                    Spacer()
                }
                .listRowSeparator(.hidden)

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
                        Task { await playerService.playQueue(trackIDs: tracks.map(\.id), startAt: tracks.firstIndex(where: { $0.id == track.id }) ?? 0) }
                    }
                }
            }
        }
        .navigationTitle(album.title)
        .task { tracks = await libraryViewModel.tracksForAlbum(album.id) }
    }
}
