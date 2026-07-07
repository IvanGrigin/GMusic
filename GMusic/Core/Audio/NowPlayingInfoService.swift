import Foundation
import MediaPlayer

/// Drives the Lock Screen / Control Center now-playing surface.
final class NowPlayingInfoService {
    func update(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        elapsedTime: TimeInterval,
        playbackRate: Float,
        isPlaying: Bool,
        artwork: MPMediaItemArtwork?
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0.0
        ]
        if let album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
}
