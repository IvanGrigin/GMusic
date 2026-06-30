import Foundation

@MainActor
final class ImportInboxViewModel: ObservableObject {
    @Published var records: [ImportRecord] = []
    @Published var isImporting = false
    @Published var lastImportSummary: String?
    @Published var errorMessage: String?
    @Published private(set) var connectedFolderURL: URL?

    private let importPipeline: ImportPipeline
    private let importRecordRepository: ImportRecordRepository
    private let importScanner: ImportScanner
    private let folderBookmarkStore: FolderBookmarkStore

    init(
        importPipeline: ImportPipeline,
        importRecordRepository: ImportRecordRepository,
        importScanner: ImportScanner,
        folderBookmarkStore: FolderBookmarkStore
    ) {
        self.importPipeline = importPipeline
        self.importRecordRepository = importRecordRepository
        self.importScanner = importScanner
        self.folderBookmarkStore = folderBookmarkStore
        connectedFolderURL = folderBookmarkStore.resolveBookmarkedFolder()
    }

    func loadRecords() async {
        records = (try? await importRecordRepository.listRecentlyImported(limit: 100)) ?? []
    }

    func importFiles(urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }
        let outcomes = await importPipeline.importFiles(sourceURLs: urls, isSecurityScoped: true)
        summarize(outcomes)
        await loadRecords()
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
        isImporting = true
        defer { isImporting = false }
        do {
            try await SecurityScopedAccess.withAccessAsync(to: folderURL) {
                let files = self.importScanner.findAudioFiles(in: folderURL)
                let outcomes = await self.importPipeline.importFiles(sourceURLs: files, isSecurityScoped: false)
                self.summarize(outcomes)
            }
            await loadRecords()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func summarize(_ outcomes: [ImportOutcome]) {
        let imported = outcomes.filter { $0.status == .databaseCommitted || $0.status == .sourceDeleted }.count
        let duplicates = outcomes.filter { $0.status == .skippedDuplicate }.count
        let failed = outcomes.filter { $0.status == .failed }.count
        lastImportSummary = "Imported \(imported), skipped \(duplicates) duplicates, \(failed) failed."
    }
}
