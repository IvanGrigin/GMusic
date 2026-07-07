import Foundation
import SwiftData

@Model
final class Playlist: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String?
    var alternateTitles: [String]
    var artworkID: UUID?
    var trackIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        alternateTitles: [String] = [],
        artworkID: UUID? = nil,
        trackIDs: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.alternateTitles = alternateTitles
        self.artworkID = artworkID
        self.trackIDs = trackIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
