import Testing
import Foundation
@testable import GMusic

struct FileHashingServiceTests {
    private let service = FileHashingService()

    @Test func sameContentProducesSameHash() throws {
        let urlA = try writeTempFile(contents: "hello world")
        let urlB = try writeTempFile(contents: "hello world")
        defer {
            try? FileManager.default.removeItem(at: urlA)
            try? FileManager.default.removeItem(at: urlB)
        }

        let hashA = try service.sha256(url: urlA)
        let hashB = try service.sha256(url: urlB)
        #expect(hashA == hashB)
    }

    @Test func differentContentProducesDifferentHash() throws {
        let urlA = try writeTempFile(contents: "hello world")
        let urlB = try writeTempFile(contents: "goodbye world")
        defer {
            try? FileManager.default.removeItem(at: urlA)
            try? FileManager.default.removeItem(at: urlB)
        }

        let hashA = try service.sha256(url: urlA)
        let hashB = try service.sha256(url: urlB)
        #expect(hashA != hashB)
    }

    @Test func throwsForMissingFile() {
        let missingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(throws: FileHashingError.self) {
            try service.sha256(url: missingURL)
        }
    }

    private func writeTempFile(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
