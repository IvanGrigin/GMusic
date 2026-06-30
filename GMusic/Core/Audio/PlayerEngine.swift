import Foundation
import AVFoundation

/// Thin wrapper around AVPlayer. Knows nothing about tracks, queues, or the database.
final class PlayerEngine {
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var timeObserverToken: Any?

    var onItemDidEnd: (() -> Void)?
    var onTimeUpdate: ((TimeInterval) -> Void)?

    func load(url: URL) {
        removeObservers()
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.onItemDidEnd?()
        }

        timeObserverToken = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.onTimeUpdate?(CMTimeGetSeconds(time))
        }
    }

    func play() { player?.play() }
    func pause() { player?.pause() }

    func seek(to seconds: TimeInterval) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    var duration: TimeInterval {
        guard let duration = player?.currentItem?.duration else { return 0 }
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite ? seconds : 0
    }

    private func removeObservers() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let timeObserverToken, let player {
            player.removeTimeObserver(timeObserverToken)
        }
        endObserver = nil
        timeObserverToken = nil
    }

    deinit {
        removeObservers()
    }
}
