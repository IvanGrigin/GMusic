import SwiftUI

struct QueueView: View {
    let appEnvironment: AppEnvironment
    @EnvironmentObject var playerService: PlayerService
    @State private var queueTracks: [UUID: Track] = [:]

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(playerService.queueItems.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        ArtworkView(imageURL: queueTracks[item.trackID]?.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) })
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading) {
                            Text(queueTracks[item.trackID]?.title ?? "—")
                            Text(queueTracks[item.trackID]?.artistName ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if playerService.currentTrack?.id == item.trackID {
                            Image(systemName: "speaker.wave.2.fill").foregroundStyle(AppColors.accent)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await playerService.playQueue(trackIDs: playerService.queueItems.map(\.trackID), startAt: index) }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        playerService.removeFromQueue(at: index)
                    }
                }
                .onMove { source, destination in
                    playerService.moveInQueue(from: source, to: destination)
                }
            }
            .navigationTitle("Up Next")
            .toolbar { EditButton() }
            .task { await loadTrackDetails() }
            .onChange(of: playerService.queueItems) { _, _ in
                Task { await loadTrackDetails() }
            }
        }
    }

    private func loadTrackDetails() async {
        let missingIDs = playerService.queueItems.map(\.trackID).filter { queueTracks[$0] == nil }
        guard !missingIDs.isEmpty else { return }
        let tracks = try? await appEnvironment.trackRepository.listTracks(ids: missingIDs)
        for track in tracks ?? [] {
            queueTracks[track.id] = track
        }
    }
}
