import Foundation
import CryptoKit

enum FileHashingError: Error {
    case cannotOpenFile
}

/// Streams the file in chunks so multi-hundred-MB FLACs don't get loaded into memory at once.
struct FileHashingService {
    func sha256(url: URL) throws -> String {
        guard let fileHandle = FileHandle(forReadingAtPath: url.path) else {
            throw FileHashingError.cannotOpenFile
        }
        defer { fileHandle.closeFile() }

        var hasher = SHA256()
        while true {
            let chunk = fileHandle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func sha256Async(url: URL) async throws -> String {
        try await Task.detached { try self.sha256(url: url) }.value
    }
}
