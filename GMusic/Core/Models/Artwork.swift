import Foundation
import SwiftData

enum ArtworkSource: String, Codable {
    case embeddedInAudio
    case userSelectedFromPhotos
    case userSelectedFromFiles
    case generatedPlaylistCollage
}

@Model
final class Artwork: Identifiable {
    @Attribute(.unique) var id: UUID
    var relativePath: String
    var source: ArtworkSource
    var width: Int
    var height: Int
    var fileSizeBytes: Int64
    var createdAt: Date

    init(
        id: UUID = UUID(),
        relativePath: String,
        source: ArtworkSource,
        width: Int,
        height: Int,
        fileSizeBytes: Int64,
        createdAt: Date = .now
    ) {
        self.id = id
        self.relativePath = relativePath
        self.source = source
        self.width = width
        self.height = height
        self.fileSizeBytes = fileSizeBytes
        self.createdAt = createdAt
    }
}
