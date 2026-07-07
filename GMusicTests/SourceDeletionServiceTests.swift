import Testing
import Foundation
@testable import GMusic

struct SourceDeletionServiceTests {
    @Test func refusesToDeleteFileInsideAppLibrary() async throws {
        let env = try makeEnv()
        defer { cleanup(env) }

        let insideURL = env.paths.audioDirectory.appendingPathComponent("track.mp3")
        try "audio".write(to: insideURL, atomically: true, encoding: .utf8)

        await #expect(throws: SourceDeletionError.sourceInsideAppLibrary) {
            try await env.service.deleteSourceIfSafe(sourceURL: insideURL, expectedHash: "anyhash", libraryRelativePath: "Audio/track.mp3")
        }
        #expect(FileManager.default.fileExists(atPath: insideURL.path))
    }

    @Test func refusesToDeleteWhenLibraryCopyMissing() async throws {
        let env = try makeEnv()
        defer { cleanup(env) }

        let sourceURL = env.tempDir.appendingPathComponent("source.mp3")
        try "audio".write(to: sourceURL, atomically: true, encoding: .utf8)

        await #expect(throws: SourceDeletionError.libraryFileMissing) {
            try await env.service.deleteSourceIfSafe(sourceURL: sourceURL, expectedHash: "anyhash", libraryRelativePath: "Audio/does-not-exist.mp3")
        }
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    @Test func refusesToDeleteWhenHashDoesNotMatch() async throws {
        let env = try makeEnv()
        defer { cleanup(env) }

        let libraryURL = env.paths.audioDirectory.appendingPathComponent("track.mp3")
        try "audio".write(to: libraryURL, atomically: true, encoding: .utf8)

        let sourceURL = env.tempDir.appendingPathComponent("source.mp3")
        try "audio".write(to: sourceURL, atomically: true, encoding: .utf8)

        await #expect(throws: SourceDeletionError.hashMismatch) {
            try await env.service.deleteSourceIfSafe(sourceURL: sourceURL, expectedHash: "wronghash", libraryRelativePath: "Audio/track.mp3")
        }
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    @Test func deletesSourceWhenAllChecksPass() async throws {
        let env = try makeEnv()
        defer { cleanup(env) }

        let libraryURL = env.paths.audioDirectory.appendingPathComponent("track.mp3")
        try "audio".write(to: libraryURL, atomically: true, encoding: .utf8)

        let sourceURL = env.tempDir.appendingPathComponent("source.mp3")
        try "audio".write(to: sourceURL, atomically: true, encoding: .utf8)
        let hash = try env.hashingService.sha256(url: sourceURL)

        try await env.service.deleteSourceIfSafe(sourceURL: sourceURL, expectedHash: hash, libraryRelativePath: "Audio/track.mp3")
        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
    }

    // MARK: - Test fixture

    private struct Environment {
        let tempDir: URL
        let paths: StoragePaths
        let hashingService: FileHashingService
        let service: SourceDeletionService
    }

    private func makeEnv() throws -> Environment {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = tempDir.appendingPathComponent("GMusic")
        let paths = StoragePaths(
            root: root,
            audioDirectory: root.appendingPathComponent("Audio"),
            artworkDirectory: root.appendingPathComponent("Artwork"),
            databaseDirectory: root.appendingPathComponent("Database"),
            importsStagingDirectory: root.appendingPathComponent("Imports/Staging"),
            cacheDirectory: root.appendingPathComponent("Cache")
        )
        try paths.createDirectoriesIfNeeded()
        let storage = FileStorage(paths: paths)
        let hashingService = FileHashingService()
        let service = SourceDeletionService(fileStorage: storage, fileHashingService: hashingService)
        return Environment(tempDir: tempDir, paths: paths, hashingService: hashingService, service: service)
    }

    private func cleanup(_ env: Environment) {
        try? FileManager.default.removeItem(at: env.tempDir)
    }
}
