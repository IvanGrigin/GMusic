import Foundation

struct ParsedFilename {
    var artist: String?
    var title: String
    var trackNumber: Int?
}

/// Used as a fallback when embedded tags are missing. Handles:
/// "Artist - Title.mp3", "01 - Artist - Title.mp3", "01. Title.mp3"
struct FilenameParser {
    func parse(fileName: String) -> ParsedFilename {
        let nameWithoutExtension = (fileName as NSString).deletingPathExtension
        var remainder = Substring(nameWithoutExtension)
        var trackNumber: Int?

        if let (number, rest) = extractLeadingTrackNumber(remainder) {
            trackNumber = number
            remainder = rest
        }

        let components = remainder
            .components(separatedBy: " - ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if components.count >= 2 {
            return ParsedFilename(
                artist: components.first,
                title: components.dropFirst().joined(separator: " - "),
                trackNumber: trackNumber
            )
        }

        return ParsedFilename(
            artist: nil,
            title: remainder.trimmingCharacters(in: .whitespaces),
            trackNumber: trackNumber
        )
    }

    private func extractLeadingTrackNumber(_ string: Substring) -> (Int, Substring)? {
        var characters = string
        var digits = ""
        while let first = characters.first, first.isNumber {
            digits.append(first)
            characters.removeFirst()
        }
        guard !digits.isEmpty, let number = Int(digits) else { return nil }

        while let first = characters.first, first == " " || first == "-" || first == "." {
            characters.removeFirst()
        }
        return (number, characters)
    }
}
