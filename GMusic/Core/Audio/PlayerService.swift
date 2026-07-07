import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import WidgetKit

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
    @Published private(set) var isQueueReversed = false
    @Published private(set) var isSongReversed = false
    @Published private(set) var playbackRate: Float = 1.0
    @Published var playbackErrorMessage: String?

    private let engine = PlayerEngine()
    private let queueManager = QueueManager()
    private let nowPlayingInfoService = NowPlayingInfoService()
    private let reverseAudioRenderer: ReverseAudioRenderer
    private let trackRepository: TrackRepository
    private let fileStorage: FileStorage
    private let artworkFileStore: ArtworkFileStore
    private let widgetSharedStore = WidgetSharedStore()
    private let liveActivityManager = NowPlayingLiveActivityManager()
    private var darwinCommandObserver: DarwinPlaybackCommandObserver?
    private var lastHandledExternalCommandAt: Date?
    private var lastBroadcastSnapshot: NowPlayingWidgetSnapshot?
    private var lastSharedArtworkTrackID: UUID?

    init(trackRepository: TrackRepository, fileStorage: FileStorage, artworkFileStore: ArtworkFileStore) {
        self.trackRepository = trackRepository
        self.fileStorage = fileStorage
        self.artworkFileStore = artworkFileStore
        self.reverseAudioRenderer = ReverseAudioRenderer(cacheDirectory: fileStorage.paths.cacheDirectory)
        configureAudioSession()
        configureRemoteCommands()
        darwinCommandObserver = DarwinPlaybackCommandObserver { [weak self] in
            Task { @MainActor in
                await self?.handlePendingExternalCommand()
            }
        }

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
        syncQueueState()
        await loadCurrentItem(autoplay: true)
    }

    func jumpToQueueIndex(_ index: Int) async {
        queueManager.jumpTo(index: index)
        syncQueueState()
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
        engine.play(at: playbackRate)
        isPlaying = true
        updateNowPlaying()
    }

    func seek(to seconds: TimeInterval) {
        engine.seek(to: seconds)
        currentTime = seconds
        updateNowPlaying()
    }

    func seekToDisplayTime(_ seconds: TimeInterval) {
        seek(to: engineTime(forDisplayTime: seconds))
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = min(max(rate, 0.5), 30.0)
        engine.setPlaybackRate(playbackRate, isPlaying: isPlaying)
        updateNowPlaying()
    }

    var displayCurrentTime: TimeInterval {
        displayTime(forEngineTime: currentTime)
    }

    func next() async {
        guard queueManager.advanceToNext() != nil else {
            isPlaying = false
            updateNowPlaying()
            return
        }
        syncQueueState()
        await loadCurrentItem(autoplay: true)
    }

    func previous() async {
        guard queueManager.advanceToPrevious() != nil else { return }
        syncQueueState()
        await loadCurrentItem(autoplay: true)
    }

    func toggleShuffle() {
        queueManager.toggleShuffle()
        syncQueueState()
    }

    func toggleQueueReverse() {
        queueManager.toggleReverseOrder()
        syncQueueState()
    }

    func toggleSongReverse() async {
        let previousValue = isSongReversed
        let wasPlaying = isPlaying
        let mirroredStartTime = duration > 0 ? max(duration - currentTime, 0) : 0

        isSongReversed.toggle()

        guard currentTrack != nil else { return }
        await loadCurrentItem(
            autoplay: wasPlaying,
            startTime: mirroredStartTime,
            incrementPlayCount: false
        )

        if previousValue == isSongReversed {
            return
        }
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
        syncQueueState()
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        queueManager.move(fromOffsets: source, toOffset: destination)
        syncQueueState()
    }

    // MARK: - Private

    private func syncQueueState() {
        queueItems = queueManager.items
        isShuffling = queueManager.shuffleEnabled
        isQueueReversed = queueManager.reverseOrderEnabled
    }

    private func loadCurrentItem(
        autoplay: Bool,
        startTime: TimeInterval? = nil,
        incrementPlayCount: Bool = true
    ) async {
        guard let item = queueManager.currentItem,
              let track = try? await trackRepository.fetchTrack(id: item.trackID) else {
            currentTrack = nil
            isPlaying = false
            return
        }

        currentTrack = track
        let sourceURL = fileStorage.absoluteURL(forRelativePath: track.fileRelativePath)
        let playbackURL = await resolvedPlaybackURL(for: track, sourceURL: sourceURL)

        engine.load(url: playbackURL)
        duration = track.durationSeconds

        if let startTime {
            currentTime = startTime
            engine.seek(to: startTime)
        } else {
            currentTime = 0
        }

        if autoplay {
            engine.play(at: playbackRate)
            isPlaying = true
        } else {
            isPlaying = false
        }

        if incrementPlayCount {
            try? await trackRepository.incrementPlayCount(id: track.id)
        }
        updateNowPlaying()
    }

    private func resolvedPlaybackURL(for track: Track, sourceURL: URL) async -> URL {
        guard isSongReversed else { return sourceURL }
        do {
            return try await reverseAudioRenderer.reversedURL(for: track, sourceURL: sourceURL)
        } catch {
            playbackErrorMessage = "Reverse playback is unavailable for this track. Falling back to normal playback."
            isSongReversed = false
            return sourceURL
        }
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
            widgetSharedStore.clearNowPlaying()
            lastBroadcastSnapshot = nil
            lastSharedArtworkTrackID = nil
            WidgetCenter.shared.reloadAllTimelines()
            Task { await liveActivityManager.end() }
            return
        }
        var artwork: MPMediaItemArtwork?
        var artworkURL: URL?
        if let artworkID = currentTrack.artworkID {
            let url = artworkFileStore.url(forRelativePath: "Artwork/\(artworkID.uuidString).jpg")
            artworkURL = url
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
            playbackRate: playbackRate,
            isPlaying: isPlaying,
            artwork: artwork
        )

        let sharedArtworkFileName: String?
        if lastSharedArtworkTrackID != currentTrack.id {
            sharedArtworkFileName = widgetSharedStore.storeArtwork(from: artworkURL)
            lastSharedArtworkTrackID = currentTrack.id
        } else {
            sharedArtworkFileName = lastBroadcastSnapshot?.artworkFileName
        }

        let snapshot = NowPlayingWidgetSnapshot(
            trackID: currentTrack.id.uuidString,
            title: currentTrack.title,
            artist: currentTrack.artistName,
            isPlaying: isPlaying,
            elapsedTime: currentTime,
            duration: duration,
            artworkFileName: sharedArtworkFileName,
            updatedAt: .now
        )
        widgetSharedStore.saveNowPlaying(snapshot)

        let requiresWidgetReload = lastBroadcastSnapshot?.trackID != snapshot.trackID ||
            lastBroadcastSnapshot?.title != snapshot.title ||
            lastBroadcastSnapshot?.artist != snapshot.artist ||
            lastBroadcastSnapshot?.isPlaying != snapshot.isPlaying ||
            lastBroadcastSnapshot?.artworkFileName != snapshot.artworkFileName

        lastBroadcastSnapshot = snapshot
        if requiresWidgetReload {
            WidgetCenter.shared.reloadAllTimelines()
        }
        Task { await liveActivityManager.startOrUpdate(with: snapshot) }
    }

    private func handlePendingExternalCommand() async {
        guard let pending = widgetSharedStore.consumePendingPlaybackCommand(after: lastHandledExternalCommandAt) else {
            return
        }
        lastHandledExternalCommandAt = pending.issuedAt

        switch pending.command {
        case .playPause:
            togglePlayPause()
        case .next:
            await next()
        case .previous:
            await previous()
        }
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
            self?.seekToDisplayTime(event.positionTime)
            return .success
        }
    }

    private func displayTime(forEngineTime seconds: TimeInterval) -> TimeInterval {
        guard isSongReversed, duration > 0 else {
            return max(seconds, 0)
        }
        return min(max(duration - seconds, 0), duration)
    }

    private func engineTime(forDisplayTime seconds: TimeInterval) -> TimeInterval {
        let clamped = min(max(seconds, 0), duration)
        guard isSongReversed, duration > 0 else {
            return clamped
        }
        return max(duration - clamped, 0)
    }
}

private actor ReverseAudioRenderer {
    enum ReverseAudioError: LocalizedError {
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "This audio format cannot be reversed."
            }
        }
    }

    private let cacheDirectory: URL
    private var inFlightTasks: [String: Task<URL, Error>] = [:]

    init(cacheDirectory: URL) {
        self.cacheDirectory = cacheDirectory
    }

    func reversedURL(for track: Track, sourceURL: URL) async throws -> URL {
        let key = track.fileHashSHA256
        let outputURL = cacheDirectory.appendingPathComponent("\(key)-reversed.caf")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            return outputURL
        }
        if let existingTask = inFlightTasks[key] {
            return try await existingTask.value
        }

        let task = Task { () throws -> URL in
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            try Self.renderReversedAudio(sourceURL: sourceURL, outputURL: outputURL)
            return outputURL
        }
        inFlightTasks[key] = task
        defer { inFlightTasks.removeValue(forKey: key) }
        return try await task.value
    }

    private static func renderReversedAudio(sourceURL: URL, outputURL: URL) throws {
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        let format = sourceFile.processingFormat
        guard !format.isInterleaved else { throw ReverseAudioError.unsupportedFormat }

        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )

        let totalFrames = sourceFile.length
        let chunkSize: AVAudioFrameCount = 16_384
        var remainingFrames = totalFrames

        while remainingFrames > 0 {
            let framesToRead = min(Int64(chunkSize), remainingFrames)
            let startFrame = remainingFrames - framesToRead
            sourceFile.framePosition = startFrame

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(framesToRead)
            ) else {
                throw ReverseAudioError.unsupportedFormat
            }

            try sourceFile.read(into: buffer, frameCount: AVAudioFrameCount(framesToRead))
            try reverseSamples(in: buffer)
            try outputFile.write(from: buffer)
            remainingFrames = startFrame
        }
    }

    private static func reverseSamples(in buffer: AVAudioPCMBuffer) throws {
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            guard let channelData = buffer.floatChannelData else { throw ReverseAudioError.unsupportedFormat }
            for channel in 0 ..< channelCount {
                reverseChannelData(channelData[channel], frameCount: frameCount)
            }
        case .pcmFormatInt16:
            guard let channelData = buffer.int16ChannelData else { throw ReverseAudioError.unsupportedFormat }
            for channel in 0 ..< channelCount {
                reverseChannelData(channelData[channel], frameCount: frameCount)
            }
        case .pcmFormatInt32:
            guard let channelData = buffer.int32ChannelData else { throw ReverseAudioError.unsupportedFormat }
            for channel in 0 ..< channelCount {
                reverseChannelData(channelData[channel], frameCount: frameCount)
            }
        default:
            throw ReverseAudioError.unsupportedFormat
        }
    }

    private static func reverseChannelData<T>(_ pointer: UnsafeMutablePointer<T>, frameCount: Int) {
        var start = 0
        var end = frameCount - 1
        while start < end {
            let tmp = pointer[start]
            pointer[start] = pointer[end]
            pointer[end] = tmp
            start += 1
            end -= 1
        }
    }
}
