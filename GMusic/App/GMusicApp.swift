import SwiftUI

@main
struct GMusicApp: App {
    @StateObject private var bootstrapper = AppBootstrapper()

    var body: some Scene {
        WindowGroup {
            switch bootstrapper.state {
            case .loading:
                ProgressView("Loading…")
            case .failed(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text("Failed to start GMusic")
                        .font(.headline)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            case .ready(let appEnvironment):
                RootView(appEnvironment: appEnvironment)
                    .task { await bootstrapper.runStartupTasks(appEnvironment: appEnvironment) }
            }
        }
    }
}

@MainActor
final class AppBootstrapper: ObservableObject {
    enum State {
        case loading
        case failed(String)
        case ready(AppEnvironment)
    }

    @Published private(set) var state: State = .loading
    private var hasStartedStartupTasks = false

    init() {
        do {
            let environment = try AppEnvironment()
            state = .ready(environment)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func runStartupTasks(appEnvironment: AppEnvironment) async {
        guard !hasStartedStartupTasks else { return }
        hasStartedStartupTasks = true
        await appEnvironment.appearanceSettings.applyAppIcon()
        let startupMaintenance = StartupMaintenanceRunner(
            importPipeline: appEnvironment.importPipeline,
            importScanner: appEnvironment.importScanner,
            folderBookmarkStore: appEnvironment.folderBookmarkStore,
            importPolicy: appEnvironment.importPolicy,
            librarySnapshotStore: appEnvironment.librarySnapshotStore
        )
        Task.detached(priority: .utility) {
            await startupMaintenance.run()
        }
    }
}

actor StartupMaintenanceRunner {
    private let importPipeline: ImportPipeline
    private let importScanner: ImportScanner
    private let folderBookmarkStore: FolderBookmarkStore
    private let importPolicy: ImportPolicy
    private let librarySnapshotStore: LibrarySnapshotStore

    init(
        importPipeline: ImportPipeline,
        importScanner: ImportScanner,
        folderBookmarkStore: FolderBookmarkStore,
        importPolicy: ImportPolicy,
        librarySnapshotStore: LibrarySnapshotStore
    ) {
        self.importPipeline = importPipeline
        self.importScanner = importScanner
        self.folderBookmarkStore = folderBookmarkStore
        self.importPolicy = importPolicy
        self.librarySnapshotStore = librarySnapshotStore
    }

    func run() async {
        _ = try? await importPipeline.recoverUnfinishedImports()
        _ = await librarySnapshotStore.refreshSnapshot()

        guard importPolicy.scanDownloadsOnLaunch,
              folderBookmarkStore.hasBookmarkedFolder,
              let folderURL = folderBookmarkStore.resolveBookmarkedFolder() else {
            return
        }

        try? await SecurityScopedAccess.withAccessAsync(to: folderURL) {
            let files = importScanner.findAudioFiles(in: folderURL)
            guard !files.isEmpty else { return }
            _ = await importPipeline.importFiles(sourceURLs: files, isSecurityScoped: false)
        }
        _ = await librarySnapshotStore.refreshSnapshot()
    }
}
