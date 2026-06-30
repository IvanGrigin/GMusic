import SwiftUI

struct StorageView: View {
    @StateObject private var viewModel: StorageViewModel
    @State private var isPickingFolder = false

    init(appEnvironment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: StorageViewModel(
            fileStorage: appEnvironment.fileStorage,
            storagePaths: appEnvironment.storagePaths,
            trackRepository: appEnvironment.trackRepository,
            externalDuplicateScanner: appEnvironment.externalDuplicateScanner,
            externalDuplicateCleaner: appEnvironment.externalDuplicateCleaner
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Library") {
                    LabeledContent("Tracks", value: "\(viewModel.trackCount)")
                    LabeledContent("Audio Size", value: viewModel.formattedAudioSize)
                    LabeledContent("Artwork Size", value: viewModel.formattedArtworkSize)
                }

                Section("Find Duplicates Outside the Library") {
                    Button {
                        isPickingFolder = true
                    } label: {
                        Label("Scan a Folder", systemImage: "magnifyingglass")
                    }
                    .disabled(viewModel.isScanning)

                    if viewModel.isScanning {
                        ProgressView()
                    }

                    if !viewModel.duplicates.isEmpty {
                        ForEach(viewModel.duplicates, id: \.fileURL) { match in
                            Text(match.fileURL.lastPathComponent)
                                .font(.footnote)
                        }
                        Button(role: .destructive) {
                            Task { await viewModel.deleteDuplicates() }
                        } label: {
                            Label("Delete \(viewModel.duplicates.count) Duplicate File(s)", systemImage: "trash")
                        }
                    }

                    if let summary = viewModel.lastCleanupSummary {
                        Text(summary).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Storage")
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
            .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    Task { await viewModel.scanFolder(url) }
                }
            }
        }
        .task { await viewModel.refreshStats() }
    }
}
