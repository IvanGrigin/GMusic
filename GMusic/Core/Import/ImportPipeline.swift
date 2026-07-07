import Foundation

struct ImportOutcome {
    let recordID: UUID
    let status: ImportStatus
    let trackID: UUID?
    let errorMessage: String?
}

/// Orchestrates the full lifecycle of importing a file:
/// copy to staging -> hash -> duplicate check -> read metadata -> move into the
/// library -> verify the moved copy's hash -> commit to the database -> only then,
/// optionally, delete the source. Each step updates the ImportRecord so a crash
/// mid-import never leaves a source file deleted without a matching Track.
final class ImportPipeline {
    private let fileStorage: FileStorage
    private let artworkFileStore: ArtworkFileStore
    private let fileHashingService: FileHashingService
    private let metadataReader: MetadataReader
    private let artworkExtractor: EmbeddedArtworkExtractor
    private let filenameParser: FilenameParser
    private let trackRepository: TrackRepository
    private let albumRepository: AlbumRepository
    private let importRecordRepository: ImportRecordRepository
    private let sourceDeletionService: SourceDeletionService
    private let duplicateDetector: DuplicateDetector
    private(set) var policy: ImportPolicy

    init(
        fileStorage: FileStorage,
        artworkFileStore: ArtworkFileStore,
        fileHashingService: FileHashingService,
        metadataReader: MetadataReader,
        artworkExtractor: EmbeddedArtworkExtractor,
        filenameParser: FilenameParser,
        trackRepository: TrackRepository,
        albumRepository: AlbumRepository,
        importRecordRepository: ImportRecordRepository,
        policy: ImportPolicy = ImportPolicy()
    ) {
        self.fileStorage = fileStorage
        self.artworkFileStore = artworkFileStore
        self.fileHashingService = fileHashingService
        self.metadataReader = metadataReader
        self.artworkExtractor = artworkExtractor
        self.filenameParser = filenameParser
        self.trackRepository = trackRepository
        self.albumRepository = albumRepository
        self.importRecordRepository = importRecordRepository
        self.sourceDeletionService = SourceDeletionService(fileStorage: fileStorage, fileHashingService: fileHashingService)
        self.duplicateDetector = DuplicateDetector(trackRepository: trackRepository)
        self.policy = policy
    }

    func updatePolicy(_ newPolicy: ImportPolicy) {
        policy = newPolicy
    }

    @discardableResult
    func importFiles(sourceURLs: [URL], isSecurityScoped: Bool = false) async -> [ImportOutcome] {
        let uniqueURLs = orderedUniqueURLs(from: sourceURLs)
        guard !uniqueURLs.isEmpty else { return [] }

        let parallelism = min(4, max(1, ProcessInfo.processInfo.activeProcessorCount))
        var nextIndex = 0
        var iterator = uniqueURLs.enumerated().makeIterator()
        var indexedOutcomes: [(Int, ImportOutcome)] = []

        await withTaskGroup(of: (Int, ImportOutcome).self) { group in
            while nextIndex < parallelism, let (index, url) = iterator.next() {
                nextIndex += 1
                group.addTask {
                    (index, await self.importFile(sourceURL: url, isSecurityScoped: isSecurityScoped))
                }
            }

            while let result = await group.next() {
                indexedOutcomes.append(result)
                if let (index, url) = iterator.next() {
                    group.addTask {
                        (index, await self.importFile(sourceURL: url, isSecurityScoped: isSecurityScoped))
                    }
                }
            }
        }

        return indexedOutcomes
            .sorted { $0.0 < $1.0 }
            .map(\.1)
    }

    @discardableResult
    func importFile(sourceURL: URL, isSecurityScoped: Bool) async -> ImportOutcome {
        let record = ImportRecord(
            sourceDisplayPath: sourceURL.path,
            sourceFileName: sourceURL.lastPathComponent,
            fileSizeBytes: 0
        )

        do {
            try await importRecordRepository.createRecord(record)
            guard sourceURL.isAudioFile else { throw ImportError.unsupportedFileType }

            if isSecurityScoped {
                return try await SecurityScopedAccess.withAccessAsync(to: sourceURL) {
                    try await self.runPipeline(sourceURL: sourceURL, record: record)
                }
            } else {
                return try await runPipeline(sourceURL: sourceURL, record: record)
            }
        } catch {
            let message = error.localizedDescription
            try? await importRecordRepository.updateRecord(id: record.id) { rec in
                rec.status = .failed
                rec.errorMessage = message
            }
            return ImportOutcome(recordID: record.id, status: .failed, trackID: nil, errorMessage: message)
        }
    }

    func recoverUnfinishedImports() async throws -> [ImportRecord] {
        try await importRecordRepository.listUnfinished()
    }

    // MARK: - Pipeline steps

    private func runPipeline(sourceURL: URL, record: ImportRecord) async throws -> ImportOutcome {
        let stagingURL = try fileStorage.copyToStaging(sourceURL: sourceURL)
        try await importRecordRepository.updateRecord(id: record.id) { $0.status = .copiedToStaging }

        do {
            let hash = try await fileHashingService.sha256Async(url: stagingURL)
            let fileSize = fileSizeOnDisk(at: stagingURL)

            if policy.skipExactDuplicates,
               let existing = try await duplicateDetector.findExactDuplicate(hash: hash) {
                return try await handleDuplicate(
                    existing: existing,
                    sourceURL: sourceURL,
                    stagingURL: stagingURL,
                    hash: hash,
                    fileSize: fileSize,
                    record: record
                )
            }

            return try await importNewTrack(
                sourceURL: sourceURL,
                stagingURL: stagingURL,
                hash: hash,
                fileSize: fileSize,
                record: record
            )
        } catch {
            fileStorage.removeStagingFile(at: stagingURL)
            throw error
        }
    }

    private func handleDuplicate(
        existing: Track,
        sourceURL: URL,
        stagingURL: URL,
        hash: String,
        fileSize: Int64,
        record: ImportRecord
    ) async throws -> ImportOutcome {
        fileStorage.removeStagingFile(at: stagingURL)
        try await importRecordRepository.updateRecord(id: record.id) { rec in
            rec.status = .skippedDuplicate
            rec.sourceHashSHA256 = hash
            rec.libraryTrackID = existing.id
            rec.fileSizeBytes = fileSize
        }
        if policy.deleteSourceAfterSuccessfulImport {
            try? await sourceDeletionService.deleteSourceIfSafe(
                sourceURL: sourceURL,
                expectedHash: hash,
                libraryRelativePath: existing.fileRelativePath
            )
        }
        return ImportOutcome(recordID: record.id, status: .skippedDuplicate, trackID: existing.id, errorMessage: nil)
    }

    private func importNewTrack(
        sourceURL: URL,
        stagingURL: URL,
        hash: String,
        fileSize: Int64,
        record: ImportRecord
    ) async throws -> ImportOutcome {
        let metadata = try await metadataReader.readMetadata(url: stagingURL)
        let audioInfo = try await metadataReader.readAudioInfo(url: stagingURL)
        let parsedFilename = filenameParser.parse(fileName: sourceURL.lastPathComponent)
        try await importRecordRepository.updateRecord(id: record.id) { $0.status = .metadataExtracted }

        let trackID = UUID()

        var artworkID: UUID?
        if let artwork = try await artworkExtractor.extractArtwork(url: stagingURL) {
            let newArtworkID = UUID()
            _ = try artworkFileStore.save(imageData: artwork.imageData, artworkID: newArtworkID)
            artworkID = newArtworkID
        }

        var albumID: UUID?
        if let albumTitle = metadata.album?.trimmedNonEmpty {
            albumID = try await albumRepository.findOrCreateAlbum(
                title: albumTitle,
                artistName: metadata.albumArtist?.trimmedNonEmpty ?? metadata.artist?.trimmedNonEmpty ?? "Unknown Artist"
            )
        }

        let relativePath = try fileStorage.moveStagingToLibrary(
            stagingURL: stagingURL,
            trackID: trackID,
            fileExtension: sourceURL.fileExtensionLowercased
        )
        try await importRecordRepository.updateRecord(id: record.id) { $0.status = .movedToLibrary }

        let libraryURL = fileStorage.absoluteURL(forRelativePath: relativePath)
        let libraryHash = try await fileHashingService.sha256Async(url: libraryURL)
        guard libraryHash == hash else { throw ImportError.hashMismatch }

        let track = Track(
            id: trackID,
            fileRelativePath: relativePath,
            originalSourcePath: sourceURL.path,
            originalFileName: sourceURL.lastPathComponent,
            fileHashSHA256: hash,
            fileSizeBytes: fileSize,
            title: metadata.title?.trimmedNonEmpty ?? parsedFilename.title,
            artistName: metadata.artist?.trimmedNonEmpty ?? parsedFilename.artist ?? "Unknown Artist",
            albumArtistName: metadata.albumArtist?.trimmedNonEmpty,
            albumID: albumID,
            discNumber: metadata.discNumber,
            trackNumber: metadata.trackNumber ?? parsedFilename.trackNumber,
            genre: metadata.genre?.trimmedNonEmpty,
            year: metadata.year,
            durationSeconds: audioInfo.durationSeconds,
            bitrate: audioInfo.bitrate,
            sampleRate: audioInfo.sampleRate,
            artworkID: artworkID,
            lyrics: metadata.lyrics?.trimmedNonEmpty
        )

        try await trackRepository.createTrack(track)
        try await importRecordRepository.updateRecord(id: record.id) { rec in
            rec.status = .databaseCommitted
            rec.sourceHashSHA256 = hash
            rec.libraryHashSHA256 = libraryHash
            rec.libraryRelativePath = relativePath
            rec.libraryTrackID = trackID
            rec.fileSizeBytes = fileSize
            rec.importedAt = .now
        }

        if policy.deleteSourceAfterSuccessfulImport {
            do {
                try await sourceDeletionService.deleteSourceIfSafe(
                    sourceURL: sourceURL,
                    expectedHash: hash,
                    libraryRelativePath: relativePath
                )
                try await importRecordRepository.updateRecord(id: record.id) {
                    $0.status = .sourceDeleted
                    $0.sourceDeletedAt = .now
                }
            } catch {
                // Not fatal: the track is safely in the library even if the source
                // couldn't be removed (e.g. no write access to its containing folder).
            }
        }

        return ImportOutcome(recordID: record.id, status: .databaseCommitted, trackID: trackID, errorMessage: nil)
    }

    private func fileSizeOnDisk(at url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return 0
        }
        return size.int64Value
    }

    private func orderedUniqueURLs(from urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var unique: [URL] = []
        unique.reserveCapacity(urls.count)

        for url in urls {
            let key = url.standardizedFileURL.path
            if seen.insert(key).inserted {
                unique.append(url)
            }
        }

        return unique
    }
}
