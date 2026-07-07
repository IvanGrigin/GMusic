import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var deleteSourceAfterImport: Bool
    @Published var skipExactDuplicates: Bool
    @Published var scanDownloadsOnLaunch: Bool
    @Published var theme: AppTheme
    @Published var brandStyle: AppBrandStyle
    @Published var noteSymbolStyle: AppNoteSymbolStyle

    private let appEnvironment: AppEnvironment

    init(appEnvironment: AppEnvironment) {
        self.appEnvironment = appEnvironment
        let policy = appEnvironment.importPolicy
        deleteSourceAfterImport = policy.deleteSourceAfterSuccessfulImport
        skipExactDuplicates = policy.skipExactDuplicates
        scanDownloadsOnLaunch = policy.scanDownloadsOnLaunch
        theme = appEnvironment.appearanceSettings.theme
        brandStyle = appEnvironment.appearanceSettings.brandStyle
        noteSymbolStyle = appEnvironment.appearanceSettings.noteSymbolStyle
    }

    func persist() {
        appEnvironment.importPolicy = ImportPolicy(
            deleteSourceAfterSuccessfulImport: deleteSourceAfterImport,
            skipExactDuplicates: skipExactDuplicates,
            scanDownloadsOnLaunch: scanDownloadsOnLaunch
        )
    }

    func persistAppearance() async {
        appEnvironment.appearanceSettings.setTheme(theme)
        await appEnvironment.appearanceSettings.setBrandStyle(brandStyle)
        appEnvironment.appearanceSettings.setNoteSymbolStyle(noteSymbolStyle)
    }
}
