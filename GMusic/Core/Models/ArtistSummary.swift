import Foundation

struct ArtistSummary: Identifiable, Hashable, Codable {
    let normalizedKey: String
    let displayName: String
    let alternateNames: [String]
    let trackIDs: [UUID]
    let artworkID: UUID?
    let totalDuration: Double

    var id: String { normalizedKey }
    var trackCount: Int { trackIDs.count }
}

struct ArtistMergeSuggestion: Identifiable, Hashable {
    let source: ArtistSummary
    let distance: Int

    var id: String { source.id }
}
