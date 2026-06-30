import Testing
@testable import GMusic

struct FilenameParserTests {
    private let parser = FilenameParser()

    @Test func parsesArtistDashTitle() {
        let result = parser.parse(fileName: "Daft Punk - One More Time.mp3")
        #expect(result.artist == "Daft Punk")
        #expect(result.title == "One More Time")
        #expect(result.trackNumber == nil)
    }

    @Test func parsesLeadingTrackNumberWithArtistAndTitle() {
        let result = parser.parse(fileName: "01 - Daft Punk - One More Time.flac")
        #expect(result.trackNumber == 1)
        #expect(result.artist == "Daft Punk")
        #expect(result.title == "One More Time")
    }

    @Test func parsesLeadingTrackNumberWithTitleOnly() {
        let result = parser.parse(fileName: "01. One More Time.m4a")
        #expect(result.trackNumber == 1)
        #expect(result.artist == nil)
        #expect(result.title == "One More Time")
    }

    @Test func fallsBackToFilenameAsTitle() {
        let result = parser.parse(fileName: "Untitled Track.wav")
        #expect(result.artist == nil)
        #expect(result.title == "Untitled Track")
        #expect(result.trackNumber == nil)
    }
}
