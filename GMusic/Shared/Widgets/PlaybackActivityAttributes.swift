import ActivityKit
import Foundation

struct PlaybackActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var artist: String
        var isPlaying: Bool
        var elapsedTime: TimeInterval
        var duration: TimeInterval
        var artworkFileName: String?
    }

    var trackID: String
}
