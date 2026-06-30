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

    init() {
        do {
            let environment = try AppEnvironment()
            state = .ready(environment)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func runStartupTasks(appEnvironment: AppEnvironment) async {
        _ = try? await appEnvironment.importPipeline.recoverUnfinishedImports()
        if appEnvironment.importPolicy.scanDownloadsOnLaunch,
           appEnvironment.folderBookmarkStore.hasBookmarkedFolder,
           let folderURL = appEnvironment.folderBookmarkStore.resolveBookmarkedFolder() {
            try? await SecurityScopedAccess.withAccessAsync(to: folderURL) {
                let files = appEnvironment.importScanner.findAudioFiles(in: folderURL)
                _ = await appEnvironment.importPipeline.importFiles(sourceURLs: files, isSecurityScoped: false)
            }
        }
    }
}
