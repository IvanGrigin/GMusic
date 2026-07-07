import Foundation

@MainActor
final class ImportInboxViewModel: ObservableObject {
    @Published var records: [ImportRecord] = []
    @Published var isImporting = false
    @Published var lastImportSummary: String?
    @Published var errorMessage: String?
    @Published private(set) var connectedFolderURL: URL?
    @Published private(set) var demoFolderName: String?
    @Published private(set) var demoTrackCount = 0
    @Published private(set) var demoUniqueTrackCount = 0
    @Published private(set) var demoDuplicateCount = 0
    @Published private(set) var demoFolderCount = 0
    @Published private(set) var demoDuplicateFolderName: String?
    @Published private(set) var demoStructurePreview: [String] = []
    @Published private(set) var importQueueCount = 0

    private let importPipeline: ImportPipeline
    private let importRecordRepository: ImportRecordRepository
    private let importScanner: ImportScanner
    private let folderBookmarkStore: FolderBookmarkStore
    private let demoAudioSeeder: SimulatorDemoAudioSeeder
    private let librarySnapshotStore: LibrarySnapshotStore

    init(
        importPipeline: ImportPipeline,
        importRecordRepository: ImportRecordRepository,
        importScanner: ImportScanner,
        folderBookmarkStore: FolderBookmarkStore,
        demoAudioSeeder: SimulatorDemoAudioSeeder,
        librarySnapshotStore: LibrarySnapshotStore
    ) {
        self.importPipeline = importPipeline
        self.importRecordRepository = importRecordRepository
        self.importScanner = importScanner
        self.folderBookmarkStore = folderBookmarkStore
        self.demoAudioSeeder = demoAudioSeeder
        self.librarySnapshotStore = librarySnapshotStore
        connectedFolderURL = folderBookmarkStore.resolveBookmarkedFolder()
        refreshDemoFolderDetails()
    }

    var hasDemoTracks: Bool {
        demoTrackCount > 0
    }

    func loadRecords() async {
        records = (try? await importRecordRepository.listRecentlyImported(limit: 100)) ?? []
    }

    func importFiles(urls: [URL]) async {
        guard !urls.isEmpty else { return }
        importQueueCount = urls.count
        isImporting = true
        defer {
            isImporting = false
            importQueueCount = 0
        }
        let outcomes = await importPipeline.importFiles(sourceURLs: urls, isSecurityScoped: true)
        summarize(outcomes, requestedCount: urls.count)
        await loadRecords()
        await refreshLibrarySnapshotIfNeeded(outcomes)
    }

    func importFolder(url: URL) async {
        isImporting = true
        defer {
            isImporting = false
            importQueueCount = 0
        }

        do {
            let outcomes = try await SecurityScopedAccess.withAccessAsync(to: url) {
                let files = self.importScanner.findAudioFiles(in: url)
                self.importQueueCount = files.count
                let outcomes = await self.importPipeline.importFiles(sourceURLs: files, isSecurityScoped: false)
                self.summarize(outcomes, requestedCount: files.count)
                return outcomes
            }
            await loadRecords()
            await refreshLibrarySnapshotIfNeeded(outcomes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connectFolder(url: URL) {
        do {
            try folderBookmarkStore.saveBookmark(for: url)
            connectedFolderURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnectFolder() {
        folderBookmarkStore.clearBookmark()
        connectedFolderURL = nil
    }

    func scanConnectedFolder() async {
        guard let folderURL = connectedFolderURL else { return }
        importQueueCount = 0
        isImporting = true
        defer { isImporting = false }
        do {
            let outcomes = try await SecurityScopedAccess.withAccessAsync(to: folderURL) {
                let files = self.importScanner.findAudioFiles(in: folderURL)
                self.importQueueCount = files.count
                let outcomes = await self.importPipeline.importFiles(sourceURLs: files, isSecurityScoped: false)
                self.summarize(outcomes, requestedCount: files.count)
                return outcomes
            }
            await loadRecords()
            await refreshLibrarySnapshotIfNeeded(outcomes)
        } catch {
            errorMessage = error.localizedDescription
        }
        importQueueCount = 0
    }

    func startupScanConnectedFolder() async {
        guard let folderURL = connectedFolderURL else { return }
        do {
            let outcomes = try await SecurityScopedAccess.withAccessAsync(to: folderURL) {
                let files = self.importScanner.findAudioFiles(in: folderURL)
                guard !files.isEmpty else { return [ImportOutcome]() }
                let outcomes = await self.importPipeline.importFiles(sourceURLs: files, isSecurityScoped: false)
                self.summarize(outcomes, requestedCount: files.count)
                return outcomes
            }
            await refreshLibrarySnapshotIfNeeded(outcomes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restoreDemoTracks() {
        do {
            _ = try demoAudioSeeder.prepareDemoFilesIfNeeded(forceRewrite: true)
            refreshDemoFolderDetails()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importDemoTracks() async {
        do {
            _ = try demoAudioSeeder.prepareDemoFilesIfNeeded()
            let urls = try demoAudioSeeder.demoAudioURLs()
            guard !urls.isEmpty else { return }

            isImporting = true
            defer {
                isImporting = false
                importQueueCount = 0
                refreshDemoFolderDetails()
            }

            importQueueCount = urls.count
            let outcomes = await importPipeline.importFiles(sourceURLs: urls, isSecurityScoped: false)
            summarize(outcomes, requestedCount: urls.count)
            await loadRecords()
            await refreshLibrarySnapshotIfNeeded(outcomes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importDemoFolderRecursively() async {
        do {
            guard let folderURL = try demoAudioSeeder.prepareDemoFilesIfNeeded() else { return }

            isImporting = true
            defer {
                isImporting = false
                importQueueCount = 0
                refreshDemoFolderDetails()
            }

            let files = importScanner.findAudioFiles(in: folderURL)
            importQueueCount = files.count
            let outcomes = await importPipeline.importFiles(sourceURLs: files, isSecurityScoped: false)
            summarize(outcomes, requestedCount: files.count)
            await loadRecords()
            await refreshLibrarySnapshotIfNeeded(outcomes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func summarize(_ outcomes: [ImportOutcome], requestedCount: Int) {
        let imported = outcomes.filter { $0.status == .databaseCommitted || $0.status == .sourceDeleted }.count
        let duplicates = outcomes.filter { $0.status == .skippedDuplicate }.count
        let failed = outcomes.filter { $0.status == .failed }.count
        lastImportSummary = "Processed \(requestedCount) file(s): imported \(imported), skipped \(duplicates) duplicates, \(failed) failed."
    }

    private func refreshLibrarySnapshotIfNeeded(_ outcomes: [ImportOutcome]) async {
        guard outcomes.contains(where: { $0.status == .databaseCommitted || $0.status == .sourceDeleted }) else { return }
        _ = await librarySnapshotStore.refreshSnapshot()
    }

    private func refreshDemoFolderDetails() {
        do {
            guard let folderURL = try demoAudioSeeder.demoFolderURL() else {
                demoFolderName = nil
                demoTrackCount = 0
                demoUniqueTrackCount = 0
                demoDuplicateCount = 0
                demoFolderCount = 0
                demoDuplicateFolderName = nil
                demoStructurePreview = []
                return
            }

            _ = try demoAudioSeeder.prepareDemoFilesIfNeeded()
            let summary = try demoAudioSeeder.demoFolderSummary()
            demoFolderName = folderURL.lastPathComponent
            demoTrackCount = summary.totalAudioFiles
            demoUniqueTrackCount = summary.uniqueTrackCount
            demoDuplicateCount = summary.duplicateFileCount
            demoFolderCount = summary.folderCount
            demoDuplicateFolderName = demoAudioSeeder.duplicateCleanupFolderName
            demoStructurePreview = summary.structurePreview
        } catch {
            demoFolderName = nil
            demoTrackCount = 0
            demoUniqueTrackCount = 0
            demoDuplicateCount = 0
            demoFolderCount = 0
            demoDuplicateFolderName = nil
            demoStructurePreview = []
        }
    }
}
