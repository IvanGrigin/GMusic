import Foundation
import SwiftData

@Model
final class Album: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var sortTitle: String?
    var originalTitle: String?
    var alternateTitles: [String]
    var artistName: String
    var year: Int?
    var genre: String?
    var artworkID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        sortTitle: String? = nil,
        originalTitle: String? = nil,
        alternateTitles: [String] = [],
        artistName: String,
        year: Int? = nil,
        genre: String? = nil,
        artworkID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.sortTitle = sortTitle
        self.originalTitle = originalTitle
        self.alternateTitles = alternateTitles
        self.artistName = artistName
        self.year = year
        self.genre = genre
        self.artworkID = artworkID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
