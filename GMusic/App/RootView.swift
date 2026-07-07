import SwiftUI

struct RootView: View {
    @ObservedObject var appEnvironment: AppEnvironment
    @ObservedObject var playerService: PlayerService
    @ObservedObject private var appearanceSettings: AppAppearanceSettings

    init(appEnvironment: AppEnvironment) {
        self.appEnvironment = appEnvironment
        self.playerService = appEnvironment.playerService
        self.appearanceSettings = appEnvironment.appearanceSettings
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                LibraryView(appEnvironment: appEnvironment)
                    .tabItem { Label("Library", systemImage: "music.note.list") }

                ImportInboxView(appEnvironment: appEnvironment)
                    .tabItem { Label("Import", systemImage: "tray.and.arrow.down") }

                StorageView(appEnvironment: appEnvironment)
                    .tabItem { Label("Storage", systemImage: "internaldrive") }

                SettingsView(appEnvironment: appEnvironment)
                    .tabItem { Label("Settings", systemImage: "gear") }
            }

            MiniPlayerView(appEnvironment: appEnvironment)
        }
        .tint(appearanceSettings.tintColor)
        .preferredColorScheme(appearanceSettings.preferredColorScheme)
        .environmentObject(appEnvironment)
        .environmentObject(playerService)
        .environmentObject(appearanceSettings)
    }
}
