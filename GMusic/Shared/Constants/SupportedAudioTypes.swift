import Foundation

enum SupportedAudioTypes {
    static let extensions = ["mp3", "m4a", "aac", "flac", "wav", "aiff"]

    static func isSupported(url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }
}
