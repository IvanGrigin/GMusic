import SwiftUI

struct MiniPlayerView: View {
    let appEnvironment: AppEnvironment
    @EnvironmentObject var playerService: PlayerService
    @State private var isShowingNowPlaying = false

    var body: some View {
        if playerService.currentTrack != nil {
            Button {
                isShowingNowPlaying = true
            } label: {
                HStack(spacing: 12) {
                    ArtworkView(imageURL: playerService.currentTrack?.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) })
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playerService.currentTrack?.title ?? "")
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(playerService.currentTrack?.artistName ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        playerService.togglePlayPause()
                    } label: {
                        Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                    }
                    Button {
                        Task { await playerService.next() }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.secondaryBackground)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isShowingNowPlaying) {
                NowPlayingView(appEnvironment: appEnvironment)
            }
        }
    }
}
