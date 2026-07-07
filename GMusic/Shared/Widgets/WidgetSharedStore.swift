import Foundation

enum PlaybackCommand: String, Codable, Hashable {
    case playPause
    case next
    case previous
}

struct PendingPlaybackCommand: Codable, Hashable {
    let command: PlaybackCommand
    let issuedAt: Date
}

struct NowPlayingWidgetSnapshot: Codable, Hashable {
    let trackID: String
    let title: String
    let artist: String
    let isPlaying: Bool
    let elapsedTime: TimeInterval
    let duration: TimeInterval
    let artworkFileName: String?
    let updatedAt: Date
}

struct LibraryWidgetSnapshot: Codable, Hashable {
    let trackCount: Int
    let albumCount: Int
    let playlistCount: Int
    let artistCount: Int
    let latestTrackTitle: String?
    let latestArtistName: String?
    let updatedAt: Date
}

enum WidgetSharedConstants {
    static let appGroupIdentifier = "group.com.ivangrigin.GMusic.shared"
    static let playbackCommandNotification = "group.com.ivangrigin.GMusic.shared.playback-command"
    static let artworkFileName = "current-track-artwork.jpg"
}

struct WidgetSharedStore {
    private enum Keys {
        static let pendingPlaybackCommand = "widget.pendingPlaybackCommand"
        static let nowPlayingSnapshot = "widget.nowPlayingSnapshot"
        static let librarySnapshot = "widget.librarySnapshot"
    }

    private let defaults: UserDefaults?
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        defaults = UserDefaults(suiteName: WidgetSharedConstants.appGroupIdentifier)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func saveNowPlaying(_ snapshot: NowPlayingWidgetSnapshot) {
        guard let defaults, let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: Keys.nowPlayingSnapshot)
    }

    func loadNowPlaying() -> NowPlayingWidgetSnapshot? {
        guard let defaults,
              let data = defaults.data(forKey: Keys.nowPlayingSnapshot) else {
            return nil
        }
        return try? decoder.decode(NowPlayingWidgetSnapshot.self, from: data)
    }

    func clearNowPlaying() {
        defaults?.removeObject(forKey: Keys.nowPlayingSnapshot)
        if let url = sharedArtworkURL() {
            try? fileManager.removeItem(at: url)
        }
    }

    func saveLibrarySnapshot(_ snapshot: LibraryWidgetSnapshot) {
        guard let defaults, let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: Keys.librarySnapshot)
    }

    func loadLibrarySnapshot() -> LibraryWidgetSnapshot? {
        guard let defaults,
              let data = defaults.data(forKey: Keys.librarySnapshot) else {
            return nil
        }
        return try? decoder.decode(LibraryWidgetSnapshot.self, from: data)
    }

    func sendPlaybackCommand(_ command: PlaybackCommand) {
        let pending = PendingPlaybackCommand(command: command, issuedAt: .now)
        guard let defaults, let data = try? encoder.encode(pending) else { return }
        defaults.set(data, forKey: Keys.pendingPlaybackCommand)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(WidgetSharedConstants.playbackCommandNotification as CFString)
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
    }

    func consumePendingPlaybackCommand(after lastHandledDate: Date?) -> PendingPlaybackCommand? {
        guard let defaults,
              let data = defaults.data(forKey: Keys.pendingPlaybackCommand),
              let pending = try? decoder.decode(PendingPlaybackCommand.self, from: data) else {
            return nil
        }

        if let lastHandledDate, pending.issuedAt <= lastHandledDate {
            return nil
        }

        defaults.removeObject(forKey: Keys.pendingPlaybackCommand)
        return pending
    }

    func storeArtwork(from sourceURL: URL?) -> String? {
        guard let sourceURL,
              let destinationURL = sharedArtworkURL() else {
            return nil
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return WidgetSharedConstants.artworkFileName
        } catch {
            return nil
        }
    }

    func sharedArtworkURL(fileName: String? = WidgetSharedConstants.artworkFileName) -> URL? {
        guard let fileName,
              let containerURL = fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: WidgetSharedConstants.appGroupIdentifier
              ) else {
            return nil
        }
        return containerURL.appendingPathComponent(fileName)
    }
}
