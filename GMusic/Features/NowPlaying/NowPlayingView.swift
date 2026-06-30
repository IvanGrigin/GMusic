import SwiftUI

struct NowPlayingView: View {
    let appEnvironment: AppEnvironment
    @EnvironmentObject var playerService: PlayerService
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingQueue = false
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ArtworkView(imageURL: playerService.currentTrack?.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) })
                    .frame(width: 280, height: 280)
                    .shadow(radius: 12)
                    .padding(.top, 16)

                VStack(spacing: 4) {
                    Text(playerService.currentTrack?.title ?? "Nothing Playing")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(playerService.currentTrack?.artistName ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                VStack(spacing: 4) {
                    Slider(
                        value: isScrubbing ? $scrubTime : .constant(playerService.currentTime),
                        in: 0...max(playerService.duration, 1),
                        onEditingChanged: { editing in
                            if editing {
                                scrubTime = playerService.currentTime
                                isScrubbing = true
                            } else {
                                playerService.seek(to: scrubTime)
                                isScrubbing = false
                            }
                        }
                    )
                    HStack {
                        Text(formattedTime(isScrubbing ? scrubTime : playerService.currentTime))
                        Spacer()
                        Text(formattedTime(playerService.duration))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                HStack(spacing: 36) {
                    Button {
                        playerService.toggleShuffle()
                    } label: {
                        Image(systemName: "shuffle")
                            .foregroundStyle(playerService.isShuffling ? AppColors.accent : .primary)
                    }

                    Button {
                        Task { await playerService.previous() }
                    } label: {
                        Image(systemName: "backward.fill").font(.title2)
                    }

                    Button {
                        playerService.togglePlayPause()
                    } label: {
                        Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                    }

                    Button {
                        Task { await playerService.next() }
                    } label: {
                        Image(systemName: "forward.fill").font(.title2)
                    }

                    Button {
                        playerService.cycleRepeatMode()
                    } label: {
                        Image(systemName: repeatIcon)
                            .foregroundStyle(playerService.repeatMode == .off ? .primary : AppColors.accent)
                    }
                }
                .font(.title3)

                Spacer()

                Button {
                    isShowingQueue = true
                } label: {
                    Label("Queue", systemImage: "list.bullet")
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingQueue) {
                QueueView(appEnvironment: appEnvironment)
            }
        }
    }

    private var repeatIcon: String {
        switch playerService.repeatMode {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
