import Foundation

/// Wraps `start/stopAccessingSecurityScopedResource` so every read of a user-picked
/// file or folder is properly scoped, even when an error is thrown mid-operation.
struct SecurityScopedAccess {
    static func withAccessAsync<T>(to url: URL, perform: () async throws -> T) async throws -> T {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await perform()
    }
}

/// Persists access to a folder (e.g. a user-connected "Downloads" folder) across app launches.
struct FolderBookmarkStore {
    private let defaults: UserDefaults
    private let key = "GMusic.connectedFolderBookmark"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveBookmark(for url: URL) throws {
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: key)
    }

    func resolveBookmarkedFolder() -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }
        var isStale = false
        return try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
    }

    func clearBookmark() {
        defaults.removeObject(forKey: key)
    }

    var hasBookmarkedFolder: Bool {
        defaults.data(forKey: key) != nil
    }
}
