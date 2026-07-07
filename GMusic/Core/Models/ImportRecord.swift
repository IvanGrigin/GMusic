import Foundation
import SwiftData

enum ImportStatus: String, Codable {
    case discovered
    case copiedToStaging
    case metadataExtracted
    case movedToLibrary
    case databaseCommitted
    case sourceDeleted
    case skippedDuplicate
    case failed
}

/// Tracks every file through the import pipeline so a crash mid-import
/// never leaves a source file deleted without a corresponding Track record.
@Model
final class ImportRecord: Identifiable {
    @Attribute(.unique) var id: UUID
    var sourceBookmark: Data?
    var sourceDisplayPath: String
    var sourceFileName: String
    var libraryTrackID: UUID?
    var libraryRelativePath: String?
    var sourceHashSHA256: String?
    var libraryHashSHA256: String?
    var fileSizeBytes: Int64
    var status: ImportStatus
    var errorMessage: String?
    var discoveredAt: Date
    var importedAt: Date?
    var sourceDeletedAt: Date?

    init(
        id: UUID = UUID(),
        sourceBookmark: Data? = nil,
        sourceDisplayPath: String,
        sourceFileName: String,
        libraryTrackID: UUID? = nil,
        libraryRelativePath: String? = nil,
        sourceHashSHA256: String? = nil,
        libraryHashSHA256: String? = nil,
        fileSizeBytes: Int64,
        status: ImportStatus = .discovered,
        errorMessage: String? = nil,
        discoveredAt: Date = .now,
        importedAt: Date? = nil,
        sourceDeletedAt: Date? = nil
    ) {
        self.id = id
        self.sourceBookmark = sourceBookmark
        self.sourceDisplayPath = sourceDisplayPath
        self.sourceFileName = sourceFileName
        self.libraryTrackID = libraryTrackID
        self.libraryRelativePath = libraryRelativePath
        self.sourceHashSHA256 = sourceHashSHA256
        self.libraryHashSHA256 = libraryHashSHA256
        self.fileSizeBytes = fileSizeBytes
        self.status = status
        self.errorMessage = errorMessage
        self.discoveredAt = discoveredAt
        self.importedAt = importedAt
        self.sourceDeletedAt = sourceDeletedAt
    }
}
