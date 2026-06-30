import Foundation
import AVFoundation

struct ExtractedArtwork {
    let imageData: Data
}

struct EmbeddedArtworkExtractor {
    func extractArtwork(url: URL) async throws -> ExtractedArtwork? {
        let asset = AVURLAsset(url: url)
        let commonMetadata = try await asset.load(.commonMetadata)
        let artworkItems = AVMetadataItem.metadataItems(
            from: commonMetadata,
            filteredByIdentifier: .commonIdentifierArtwork
        )
        guard let item = artworkItems.first,
              let value = try await item.load(.value),
              let data = value as? Data else {
            return nil
        }
        return ExtractedArtwork(imageData: data)
    }
}
