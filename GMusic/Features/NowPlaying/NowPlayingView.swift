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
            ScrollView {
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
                            value: isScrubbing ? $scrubTime : .constant(playerService.displayCurrentTime),
                            in: 0...max(playerService.duration, 1),
                            onEditingChanged: { editing in
                                if editing {
                                    scrubTime = playerService.displayCurrentTime
                                    isScrubbing = true
                                } else {
                                    playerService.seekToDisplayTime(scrubTime)
                                    isScrubbing = false
                                }
                            }
                        )
                        HStack {
                            Text(formattedTime(isScrubbing ? scrubTime : playerService.displayCurrentTime))
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

                    GroupBox {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                playbackModeButton(
                                    title: "Shuffle",
                                    systemImage: "shuffle",
                                    isActive: playerService.isShuffling
                                ) {
                                    playerService.toggleShuffle()
                                }

                                playbackModeButton(
                                    title: "Queue Reverse",
                                    systemImage: "arrow.left.arrow.right",
                                    isActive: playerService.isQueueReversed
                                ) {
                                    playerService.toggleQueueReverse()
                                }
                            }

                            HStack(spacing: 12) {
                                playbackModeButton(
                                    title: "Song Reverse",
                                    systemImage: "backward.frame.fill",
                                    isActive: playerService.isSongReversed
                                ) {
                                    Task { await playerService.toggleSongReverse() }
                                }

                                Button {
                                    isShowingQueue = true
                                } label: {
                                    Label("Queue", systemImage: "list.bullet")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.bordered)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Speed")
                                    Spacer()
                                    Text(String(format: "x%.1f", playerService.playbackRate))
                                        .foregroundStyle(.secondary)
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(playerService.playbackRate) },
                                        set: { playerService.setPlaybackRate(Float($0)) }
                                    ),
                                    in: 0.5...30.0,
                                    step: 0.1
                                )
                                HStack {
                                    Text("0.5x").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("30x").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } label: {
                        Label("Playback Modes", systemImage: "dial.medium")
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Playback Error", isPresented: Binding(
                get: { playerService.playbackErrorMessage != nil },
                set: { if !$0 { playerService.playbackErrorMessage = nil } }
            ), actions: {
                Button("OK") { playerService.playbackErrorMessage = nil }
            }, message: {
                Text(playerService.playbackErrorMessage ?? "")
            })
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

    private func playbackModeButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(isActive ? AppColors.accent : .secondary.opacity(0.25))
        .foregroundStyle(isActive ? .white : .primary)
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
