import Foundation

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedForSearch: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    var collapsedWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    var normalizedArtistKey: String {
        collapsedWhitespace
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    var normalizedArtistComparison: String {
        collapsedWhitespace
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    func levenshteinDistance(to other: String) -> Int {
        if self == other { return 0 }
        if isEmpty { return other.count }
        if other.isEmpty { return count }

        let source = Array(self)
        let target = Array(other)
        var previous = Array(0...target.count)

        for (sourceIndex, sourceCharacter) in source.enumerated() {
            var current = Array(repeating: 0, count: target.count + 1)
            current[0] = sourceIndex + 1

            for (targetIndex, targetCharacter) in target.enumerated() {
                let insertion = current[targetIndex] + 1
                let deletion = previous[targetIndex + 1] + 1
                let substitution = previous[targetIndex] + (sourceCharacter == targetCharacter ? 0 : 1)
                current[targetIndex + 1] = Swift.min(insertion, deletion, substitution)
            }

            previous = current
        }

        return previous[target.count]
    }
}
