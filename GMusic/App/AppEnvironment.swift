import Foundation
import SwiftData

/// Wires together storage paths, the SwiftData container, every repository,
/// and the services that sit on top of them. Built once at app launch and
/// shared down the view hierarchy.
@MainActor
final class AppEnvironment: ObservableObject {
    let modelContainer: ModelContainer
    let storagePaths: StoragePaths
    let fileStorage: FileStorage
    let artworkFileStore: ArtworkFileStore
    let fileHashingService: FileHashingService
    let folderBookmarkStore: FolderBookmarkStore
    let appearanceSettings: AppAppearanceSettings

    let trackRepository: TrackRepository
    let albumRepository: AlbumRepository
    let playlistRepository: PlaylistRepository
    let importRecordRepository: ImportRecordRepository

    let metadataReader: MetadataReader
    let artworkExtractor: EmbeddedArtworkExtractor
    let filenameParser: FilenameParser
    let demoAudioSeeder: SimulatorDemoAudioSeeder
    let importPipeline: ImportPipeline
    let importScanner: ImportScanner
    let librarySnapshotStore: LibrarySnapshotStore

    let sourceDeletionService: SourceDeletionService
    let externalDuplicateScanner: ExternalDuplicateScanner
    let externalDuplicateCleaner: ExternalDuplicateCleaner

    let playerService: PlayerService

    @Published var importPolicy: ImportPolicy {
        didSet { importPipeline.updatePolicy(importPolicy) }
    }

    init() throws {
        let paths = try StoragePaths.makeDefault()
        try paths.createDirectoriesIfNeeded()
        storagePaths = paths

        let storeURL = paths.databaseDirectory.appendingPathComponent("GMusic.store")
        modelContainer = try ModelContainerFactory.makeContainer(storeURL: storeURL)

        let storage = FileStorage(paths: paths)
        fileStorage = storage
        artworkFileStore = ArtworkFileStore(paths: paths)
        fileHashingService = FileHashingService()
        folderBookmarkStore = FolderBookmarkStore()
        appearanceSettings = AppAppearanceSettings()

        trackRepository = TrackRepository(modelContainer: modelContainer)
        albumRepository = AlbumRepository(modelContainer: modelContainer)
        playlistRepository = PlaylistRepository(modelContainer: modelContainer)
        importRecordRepository = ImportRecordRepository(modelContainer: modelContainer)

        metadataReader = MetadataReader()
        artworkExtractor = EmbeddedArtworkExtractor()
        filenameParser = FilenameParser()
        demoAudioSeeder = SimulatorDemoAudioSeeder()

        let policy = ImportPolicy()
        importPolicy = policy

        importPipeline = ImportPipeline(
            fileStorage: storage,
            artworkFileStore: artworkFileStore,
            fileHashingService: fileHashingService,
            metadataReader: metadataReader,
            artworkExtractor: artworkExtractor,
            filenameParser: filenameParser,
            trackRepository: trackRepository,
            albumRepository: albumRepository,
            importRecordRepository: importRecordRepository,
            policy: policy
        )
        importScanner = ImportScanner()
        librarySnapshotStore = LibrarySnapshotStore(
            storagePaths: paths,
            trackRepository: trackRepository,
            albumRepository: albumRepository,
            playlistRepository: playlistRepository
        )

        sourceDeletionService = SourceDeletionService(fileStorage: storage, fileHashingService: fileHashingService)
        externalDuplicateScanner = ExternalDuplicateScanner(
            fileStorage: storage,
            fileHashingService: fileHashingService,
            trackRepository: trackRepository
        )
        externalDuplicateCleaner = ExternalDuplicateCleaner(
            fileStorage: storage,
            fileHashingService: fileHashingService,
            trackRepository: trackRepository,
            sourceDeletionService: sourceDeletionService
        )

        playerService = PlayerService(
            trackRepository: trackRepository,
            fileStorage: storage,
            artworkFileStore: artworkFileStore
        )
    }
}
