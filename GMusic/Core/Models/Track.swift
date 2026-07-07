import Foundation
import SwiftData

@Model
final class Track: Identifiable {
    @Attribute(.unique) var id: UUID
    var fileRelativePath: String
    var originalSourcePath: String?
    var originalFileName: String
    @Attribute(.unique) var fileHashSHA256: String
    var fileSizeBytes: Int64

    var title: String
    var sortTitle: String?
    var originalTitle: String?
    var alternateTitles: [String]

    var artistName: String
    var albumArtistName: String?
    var albumID: UUID?
    var discNumber: Int?
    var trackNumber: Int?
    var genre: String?
    var year: Int?

    var durationSeconds: Double
    var bitrate: Int?
    var sampleRate: Int?

    var artworkID: UUID?
    var lyrics: String?
    var userTags: [String]

    var dateImported: Date
    var lastPlayedAt: Date?
    var playCount: Int
    var isFavorite: Bool
    var userRating: Int?

    init(
        id: UUID = UUID(),
        fileRelativePath: String,
        originalSourcePath: String? = nil,
        originalFileName: String,
        fileHashSHA256: String,
        fileSizeBytes: Int64,
        title: String,
        sortTitle: String? = nil,
        originalTitle: String? = nil,
        alternateTitles: [String] = [],
        artistName: String,
        albumArtistName: String? = nil,
        albumID: UUID? = nil,
        discNumber: Int? = nil,
        trackNumber: Int? = nil,
        genre: String? = nil,
        year: Int? = nil,
        durationSeconds: Double,
        bitrate: Int? = nil,
        sampleRate: Int? = nil,
        artworkID: UUID? = nil,
        lyrics: String? = nil,
        userTags: [String] = [],
        dateImported: Date = .now,
        lastPlayedAt: Date? = nil,
        playCount: Int = 0,
        isFavorite: Bool = false,
        userRating: Int? = nil
    ) {
        self.id = id
        self.fileRelativePath = fileRelativePath
        self.originalSourcePath = originalSourcePath
        self.originalFileName = originalFileName
        self.fileHashSHA256 = fileHashSHA256
        self.fileSizeBytes = fileSizeBytes
        self.title = title
        self.sortTitle = sortTitle
        self.originalTitle = originalTitle
        self.alternateTitles = alternateTitles
        self.artistName = artistName
        self.albumArtistName = albumArtistName
        self.albumID = albumID
        self.discNumber = discNumber
        self.trackNumber = trackNumber
        self.genre = genre
        self.year = year
        self.durationSeconds = durationSeconds
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.artworkID = artworkID
        self.lyrics = lyrics
        self.userTags = userTags
        self.dateImported = dateImported
        self.lastPlayedAt = lastPlayedAt
        self.playCount = playCount
        self.isFavorite = isFavorite
        self.userRating = userRating
    }
}
