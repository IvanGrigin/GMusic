import Foundation

/// Minimal artwork persistence for the MVP: artwork is just a JPEG/PNG blob on disk,
/// referenced by relative path from Track/Album/Playlist via `artworkID`.
struct ArtworkFileStore {
    let paths: StoragePaths
    private let fileManager: FileManager

    init(paths: StoragePaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func save(imageData: Data, artworkID: UUID, fileExtension: String = "jpg") throws -> String {
        let fileName = "\(artworkID.uuidString).\(fileExtension)"
        let url = paths.artworkDirectory.appendingPathComponent(fileName)
        try imageData.write(to: url, options: .atomic)
        return "Artwork/\(fileName)"
    }

    func delete(relativePath: String) {
        let url = paths.root.appendingPathComponent(relativePath)
        try? fileManager.removeItem(at: url)
    }

    func url(forRelativePath relativePath: String) -> URL {
        paths.root.appendingPathComponent(relativePath)
    }

    func url(forArtworkID artworkID: UUID, fileExtension: String = "jpg") -> URL {
        url(forRelativePath: "Artwork/\(artworkID.uuidString).\(fileExtension)")
    }
}
