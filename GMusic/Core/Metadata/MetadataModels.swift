import Foundation

struct RawAudioMetadata {
    var title: String?
    var artist: String?
    var album: String?
    var albumArtist: String?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var lyrics: String?
}

struct AudioFileInfo {
    var durationSeconds: Double
    var bitrate: Int?
    var sampleRate: Int?
}
