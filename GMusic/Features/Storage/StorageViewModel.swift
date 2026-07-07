import Foundation

@MainActor
final class StorageViewModel: ObservableObject {
    @Published var audioSizeBytes: Int64 = 0
    @Published var artworkSizeBytes: Int64 = 0
    @Published var trackCount: Int = 0
    @Published var duplicates: [ExternalDuplicateMatch] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var lastCleanupSummary: String?
    @Published private(set) var demoDuplicateFolderName: String?

    private let fileStorage: FileStorage
    private let storagePaths: StoragePaths
    private let trackRepository: TrackRepository
    private let externalDuplicateScanner: ExternalDuplicateScanner
    private let externalDuplicateCleaner: ExternalDuplicateCleaner
    private let demoAudioSeeder: SimulatorDemoAudioSeeder?

    init(
        fileStorage: FileStorage,
        storagePaths: StoragePaths,
        trackRepository: TrackRepository,
        externalDuplicateScanner: ExternalDuplicateScanner,
        externalDuplicateCleaner: ExternalDuplicateCleaner,
        demoAudioSeeder: SimulatorDemoAudioSeeder? = nil
    ) {
        self.fileStorage = fileStorage
        self.storagePaths = storagePaths
        self.trackRepository = trackRepository
        self.externalDuplicateScanner = externalDuplicateScanner
        self.externalDuplicateCleaner = externalDuplicateCleaner
        self.demoAudioSeeder = demoAudioSeeder
        demoDuplicateFolderName = demoAudioSeeder?.duplicateCleanupFolderName
    }

    func refreshStats() async {
        let fileStorage = fileStorage
        let audioDirectory = storagePaths.audioDirectory
        let artworkDirectory = storagePaths.artworkDirectory
        async let audioSize = Task.detached { fileStorage.sizeOfDirectory(audioDirectory) }.value
        async let artworkSize = Task.detached { fileStorage.sizeOfDirectory(artworkDirectory) }.value
        audioSizeBytes = await audioSize
        artworkSizeBytes = await artworkSize
        trackCount = (try? await trackRepository.listTracks()).map(\.count) ?? 0
    }

    func scanFolder(_ url: URL) async {
        isScanning = true
        defer { isScanning = false }
        do {
            duplicates = try await SecurityScopedAccess.withAccessAsync(to: url) {
                try await self.externalDuplicateScanner.findDuplicates(in: url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scanDemoDuplicateFolder() async {
        guard let demoAudioSeeder else {
            return
        }

        isScanning = true
        defer { isScanning = false }
        do {
            _ = try demoAudioSeeder.prepareDemoFilesIfNeeded()
            guard let folderURL = try demoAudioSeeder.duplicateCleanupFolderURL() else { return }
            duplicates = try await externalDuplicateScanner.findDuplicates(in: folderURL)
            lastCleanupSummary = duplicates.isEmpty ? "No duplicate files found in the demo duplicate folder." : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteDuplicates() async {
        guard !duplicates.isEmpty else { return }
        isScanning = true
        defer { isScanning = false }
        let result = await externalDuplicateCleaner.deleteDuplicates(duplicates)
        lastCleanupSummary = "Deleted \(result.deleted.count) duplicate file(s)."
        if !result.failed.isEmpty {
            errorMessage = result.failed.first?.1.localizedDescription
        }
        duplicates.removeAll { match in result.deleted.contains(match.fileURL) }
    }

    var formattedAudioSize: String { Self.formatter.string(fromByteCount: audioSizeBytes) }
    var formattedArtworkSize: String { Self.formatter.string(fromByteCount: artworkSizeBytes) }

    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
}
