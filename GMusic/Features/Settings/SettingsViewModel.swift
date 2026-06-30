import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var deleteSourceAfterImport: Bool
    @Published var skipExactDuplicates: Bool
    @Published var scanDownloadsOnLaunch: Bool

    private let appEnvironment: AppEnvironment

    init(appEnvironment: AppEnvironment) {
        self.appEnvironment = appEnvironment
        let policy = appEnvironment.importPolicy
        deleteSourceAfterImport = policy.deleteSourceAfterSuccessfulImport
        skipExactDuplicates = policy.skipExactDuplicates
        scanDownloadsOnLaunch = policy.scanDownloadsOnLaunch
    }

    func persist() {
        appEnvironment.importPolicy = ImportPolicy(
            deleteSourceAfterSuccessfulImport: deleteSourceAfterImport,
            skipExactDuplicates: skipExactDuplicates,
            scanDownloadsOnLaunch: scanDownloadsOnLaunch
        )
    }
}
