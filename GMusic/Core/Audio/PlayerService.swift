import Foundation
import AVFoundation
import MediaPlayer
import UIKit

/// The single API the UI talks to for playback. Owns the AVPlayer wrapper, the
/// queue, and Lock Screen / Control Center integration.
@MainActor
final class PlayerService: ObservableObject {
    @Published private(set) var currentTrack: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var queueItems: [QueueItem] = []
    @Published private(set) var repeatMode: RepeatMode = .off
    @Published private(set) var isShuffling = false

    private let engine = PlayerEngine()
    private let queueManager = QueueManager()
    private let nowPlayingInfoService = NowPlayingInfoService()
    private let trackRepository: TrackRepository
    private let fileStorage: FileStorage
    private let artworkFileStore: ArtworkFileStore

    init(trackRepository: TrackRepository, fileStorage: FileStorage, artworkFileStore: ArtworkFileStore) {
        self.trackRepository = trackRepository
        self.fileStorage = fileStorage
        self.artworkFileStore = artworkFileStore
        configureAudioSession()
        configureRemoteCommands()

        engine.onItemDidEnd = { [weak self] in
            Task { @MainActor in await self?.next() }
        }
        engine.onTimeUpdate = { [weak self] time in
            Task { @MainActor in self?.handleTimeUpdate(time) }
        }
    }

    func play(trackID: UUID) async {
        await playQueue(trackIDs: [trackID], startAt: 0)
    }

    func playQueue(trackIDs: [UUID], startAt: Int) async {
        queueManager.setQueue(trackIDs: trackIDs, startAt: startAt)
        queueItems = queueManager.items
        await loadCurrentItem(autoplay: true)
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        engine.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        guard currentTrack != nil else { return }
        engine.play()
        isPlaying = true
        updateNowPlaying()
    }

    func seek(to seconds: TimeInterval) {
        engine.seek(to: seconds)
        currentTime = seconds
        updateNowPlaying()
    }

    func next() async {
        guard queueManager.advanceToNext() != nil else {
            isPlaying = false
            return
        }
        queueItems = queueManager.items
        await loadCurrentItem(autoplay: true)
    }

    func previous() async {
        guard queueManager.advanceToPrevious() != nil else { return }
        queueItems = queueManager.items
        await loadCurrentItem(autoplay: true)
    }

    func toggleShuffle() {
        queueManager.toggleShuffle()
        isShuffling = queueManager.shuffleEnabled
        queueItems = queueManager.items
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
        queueManager.repeatMode = repeatMode
    }

    func removeFromQueue(at index: Int) {
        queueManager.remove(at: index)
        queueItems = queueManager.items
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        queueManager.move(fromOffsets: source, toOffset: destination)
        queueItems = queueManager.items
    }

    // MARK: - Private

    private func loadCurrentItem(autoplay: Bool) async {
        guard let item = queueManager.currentItem,
              let track = try? await trackRepository.fetchTrack(id: item.trackID) else {
            currentTrack = nil
            isPlaying = false
            return
        }
        currentTrack = track
        let url = fileStorage.absoluteURL(forRelativePath: track.fileRelativePath)
        engine.load(url: url)
        duration = track.durationSeconds
        currentTime = 0
        if autoplay {
            engine.play()
            isPlaying = true
        }
        try? await trackRepository.incrementPlayCount(id: track.id)
        updateNowPlaying()
    }

    private func handleTimeUpdate(_ time: TimeInterval) {
        currentTime = time
        if duration <= 0 {
            duration = engine.duration
        }
        updateNowPlaying()
    }

    private func updateNowPlaying() {
        guard let currentTrack else {
            nowPlayingInfoService.clear()
            return
        }
        var artwork: MPMediaItemArtwork?
        if let artworkID = currentTrack.artworkID {
            let url = artworkFileStore.url(forRelativePath: "Artwork/\(artworkID.uuidString).jpg")
            if let image = UIImage(contentsOfFile: url.path) {
                artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            }
        }
        nowPlayingInfoService.update(
            title: currentTrack.title,
            artist: currentTrack.artistName,
            album: nil,
            duration: duration,
            elapsedTime: currentTime,
            isPlaying: isPlaying,
            artwork: artwork
        )
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            // Playback simply won't start if this fails; surfaced via AVPlayer errors instead.
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in await self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in await self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }
}
