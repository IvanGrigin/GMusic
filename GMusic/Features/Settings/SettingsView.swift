import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(appEnvironment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(appEnvironment: appEnvironment))
    }

    var body: some View {
        NavigationStack {
            Form {
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
        }
    }
}
