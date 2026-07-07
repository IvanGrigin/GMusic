import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(appEnvironment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(appEnvironment: appEnvironment))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            BrandArtworkPlaceholder(cornerRadius: 22)
                                .frame(width: 120, height: 120)
                            Text("App Cover Preview")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    Picker("Theme", selection: $viewModel.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }

                    Picker("Branding", selection: $viewModel.brandStyle) {
                        ForEach(AppBrandStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }

                    Picker("Note Symbol", selection: $viewModel.noteSymbolStyle) {
                        ForEach(AppNoteSymbolStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }

                    Text("Branding changes the app icon colors, placeholder artwork, and tint. Note Symbol changes the music note shape used inside the app artwork.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Import Behavior") {
                    Toggle("Delete source after successful import", isOn: $viewModel.deleteSourceAfterImport)
                    Toggle("Skip exact duplicates", isOn: $viewModel.skipExactDuplicates)
                    Toggle("Scan connected folder on launch", isOn: $viewModel.scanDownloadsOnLaunch)
                }

                Section {
                    Text("Source files are only ever deleted after they have been copied into the app library and the copy's hash has been verified to match the original.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onChange(of: viewModel.deleteSourceAfterImport) { _, _ in viewModel.persist() }
            .onChange(of: viewModel.skipExactDuplicates) { _, _ in viewModel.persist() }
            .onChange(of: viewModel.scanDownloadsOnLaunch) { _, _ in viewModel.persist() }
            .onChange(of: viewModel.theme) { _, _ in
                Task { await viewModel.persistAppearance() }
            }
            .onChange(of: viewModel.brandStyle) { _, _ in
                Task { await viewModel.persistAppearance() }
            }
            .onChange(of: viewModel.noteSymbolStyle) { _, _ in
                Task { await viewModel.persistAppearance() }
            }
        }
    }
}
