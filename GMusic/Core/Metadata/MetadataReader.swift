import Foundation
import AVFoundation
import CoreMedia

enum MetadataReaderError: Error {
    case cannotLoadAsset
}

struct MetadataReader {
    func readMetadata(url: URL) async throws -> RawAudioMetadata {
        let asset = AVURLAsset(url: url)
        var result = RawAudioMetadata()

        let commonMetadata = try await asset.load(.commonMetadata)
        for item in commonMetadata {
            guard let key = item.commonKey else { continue }
            let value = try await item.load(.value)
            switch key {
            case .commonKeyTitle:
                result.title = value as? String
            case .commonKeyArtist:
                result.artist = value as? String
            case .commonKeyAlbumName:
                result.album = value as? String
            case .commonKeyType:
                result.genre = value as? String
            case .commonKeyCreationDate:
                if let dateString = value as? String {
                    result.year = Self.extractYear(from: dateString)
                }
            default:
                break
            }
        }

        var formatSpecificItems: [AVMetadataItem] = []
        for format in try await asset.load(.availableMetadataFormats) {
            formatSpecificItems += try await asset.loadMetadata(for: format)
        }

        result.albumArtist = try await firstStringValue(
            in: formatSpecificItems,
            identifiers: [.iTunesMetadataAlbumArtist, .id3MetadataBand]
        )
        result.lyrics = try await firstStringValue(
            in: formatSpecificItems,
            identifiers: [.iTunesMetadataLyrics, .id3MetadataUnsynchronizedLyric]
        )
        if let trackNumberString = try await firstStringValue(
            in: formatSpecificItems,
            identifiers: [.iTunesMetadataTrackNumber, .id3MetadataTrackNumber]
        ) {
            result.trackNumber = Self.extractLeadingInt(from: trackNumberString)
        }
        if let discNumberString = try await firstStringValue(
            in: formatSpecificItems,
            identifiers: [.iTunesMetadataDiscNumber, .id3MetadataPartOfASet]
        ) {
            result.discNumber = Self.extractLeadingInt(from: discNumberString)
        }

        return result
    }

    func readAudioInfo(url: URL) async throws -> AudioFileInfo {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .audio)

        var bitrate: Int?
        var sampleRate: Int?
        if let track = tracks.first {
            let formatDescriptions = try await track.load(.formatDescriptions)
            if let formatDescription = formatDescriptions.first,
               let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                sampleRate = Int(basicDescription.pointee.mSampleRate)
            }
            let estimatedRate = try await track.load(.estimatedDataRate)
            bitrate = Int(estimatedRate)
        }

        return AudioFileInfo(
            durationSeconds: CMTimeGetSeconds(duration),
            bitrate: bitrate,
            sampleRate: sampleRate
        )
    }

    private func firstStringValue(in items: [AVMetadataItem], identifiers: [AVMetadataIdentifier]) async throws -> String? {
        for identifier in identifiers {
            let matches = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier)
            if let item = matches.first {
                let value = try await item.load(.value)
                if let stringValue = value as? String {
                    return stringValue
                }
                if let numberValue = value as? NSNumber {
                    return numberValue.stringValue
                }
            }
        }
        return nil
    }

    private static func extractYear(from dateString: String) -> Int? {
        Int(dateString.prefix(4))
    }

    private static func extractLeadingInt(from value: String) -> Int? {
        let digits = value.prefix(while: \.isNumber)
        return digits.isEmpty ? nil : Int(digits)
    }
}
