import Testing
@testable import GMusic

struct ArtistMatchingTests {
    @Test func normalizesArtistKeyByCase() {
        #expect("AURORA".normalizedArtistKey == "aurora")
        #expect("  Aurora  Ensemble ".normalizedArtistKey == "aurora ensemble")
    }

    @Test func calculatesLevenshteinDistance() {
        #expect("metallica".levenshteinDistance(to: "metallika") == 1)
        #expect("daft punk".levenshteinDistance(to: "draft punk") == 1)
        #expect("aurora".levenshteinDistance(to: "aurora") == 0)
    }
}
