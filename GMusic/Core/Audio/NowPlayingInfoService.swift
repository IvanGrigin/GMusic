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
        isPlaying: Bool,
        artwork: MPMediaItemArtwork?
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
