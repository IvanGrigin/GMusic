import SwiftUI
import UniformTypeIdentifiers

struct ImportInboxView: View {
    @StateObject private var viewModel: ImportInboxViewModel
    @State private var isPickingFiles = false
    @State private var isPickingFolder = false
    @State private var isImportingFolderOnce = false

    init(appEnvironment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: ImportInboxViewModel(
            importPipeline: appEnvironment.importPipeline,
            importRecordRepository: appEnvironment.importRecordRepository,
            importScanner: appEnvironment.importScanner,
            folderBookmarkStore: appEnvironment.folderBookmarkStore,
            demoAudioSeeder: appEnvironment.demoAudioSeeder,
            librarySnapshotStore: appEnvironment.librarySnapshotStore
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                if let demoFolderName = viewModel.demoFolderName {
                    Section("Simulator Demo") {
                        Text("Simulator builds generate a nested demo library in Documents so you can test single-file import, recursive folder import, inner folders, and duplicate cleanup.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        LabeledContent("Demo Root", value: demoFolderName)
                        LabeledContent("Audio Files", value: "\(viewModel.demoTrackCount)")
                        LabeledContent("Unique Tracks", value: "\(viewModel.demoUniqueTrackCount)")
                        LabeledContent("Exact Duplicates", value: "\(viewModel.demoDuplicateCount)")
                        LabeledContent("Nested Folders", value: "\(viewModel.demoFolderCount)")

                        if let duplicateFolderName = viewModel.demoDuplicateFolderName {
                            Text("Use \(duplicateFolderName) later in Storage to test deleting duplicates outside the library.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if !viewModel.demoStructurePreview.isEmpty {
                            ForEach(viewModel.demoStructurePreview, id: \.self) { path in
                                Label(path, systemImage: "folder")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            Task { await viewModel.importDemoTracks() }
                        } label: {
                            Label("Import Demo Files", systemImage: "music.note.badge.plus")
                        }
                        .disabled(viewModel.isImporting || !viewModel.hasDemoTracks)

                        Button {
                            Task { await viewModel.importDemoFolderRecursively() }
                        } label: {
                            Label("Import Demo Folder Recursively", systemImage: "folder.badge.plus")
                        }
                        .disabled(viewModel.isImporting || !viewModel.hasDemoTracks)

                        Button {
                            viewModel.restoreDemoTracks()
                        } label: {
                            Label("Regenerate Demo Folder", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(viewModel.isImporting)
                    }
                }

                Section {
                    Button {
                        isPickingFiles = true
                    } label: {
                        Label("Import Files", systemImage: "doc.badge.plus")
                    }
                    .disabled(viewModel.isImporting)

                    Text("You can choose several songs at once from Files.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        isImportingFolderOnce = true
                    } label: {
                        Label("Import Folder Files", systemImage: "folder.badge.plus")
                    }
                    .disabled(viewModel.isImporting)

                    Text("Folder import scans inner folders recursively and will skip exact duplicates by hash when that setting is enabled.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let folderURL = viewModel.connectedFolderURL {
                        Label("Connected: \(folderURL.lastPathComponent)", systemImage: "folder.fill")
                            .foregroundStyle(.secondary)
                        Button {
                            Task { await viewModel.scanConnectedFolder() }
                        } label: {
                            Label("Scan Connected Folder", systemImage: "arrow.clockwise")
                        }
                        .disabled(viewModel.isImporting)
                        Button(role: .destructive) {
                            viewModel.disconnectFolder()
                        } label: {
                            Label("Disconnect Folder", systemImage: "folder.badge.minus")
                        }
                    } else {
                        Button {
                            isPickingFolder = true
                        } label: {
                            Label("Connect a Folder", systemImage: "folder.badge.plus")
                        }
                    }

                    if viewModel.isImporting {
                        HStack {
                            ProgressView()
                            if viewModel.importQueueCount > 0 {
                                Text("Importing \(viewModel.importQueueCount) file(s)…")
                            } else {
                                Text("Importing…")
                            }
                        }
                    }
                    if let summary = viewModel.lastImportSummary {
                        Text(summary).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Recent Imports") {
                    ForEach(viewModel.records) { record in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.sourceFileName).font(.body)
                            Text(statusDescription(record.status))
                                .font(.caption)
                                .foregroundStyle(statusColor(record.status))
                            if let errorMessage = record.errorMessage {
                                Text(errorMessage).font(.caption2).foregroundStyle(.red)
                            }
                        }
                    }
                    if viewModel.records.isEmpty {
                        Text("No imports yet").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Import")
            .alert("Import Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
            .fileImporter(
                isPresented: $isPickingFiles,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    Task { await viewModel.importFiles(urls: urls) }
                }
            }
            .fileImporter(
                isPresented: $isPickingFolder,
                allowedContentTypes: [.folder]
            ) { result in
                if case .success(let url) = result {
                    viewModel.connectFolder(url: url)
                }
            }
            .fileImporter(
                isPresented: $isImportingFolderOnce,
                allowedContentTypes: [.folder]
            ) { result in
                if case .success(let url) = result {
                    Task { await viewModel.importFolder(url: url) }
                }
            }
        }
        .task { await viewModel.loadRecords() }
    }

    private func statusDescription(_ status: ImportStatus) -> String {
        switch status {
        case .discovered: return "Discovered"
        case .copiedToStaging: return "Copying…"
        case .metadataExtracted: return "Reading metadata…"
        case .movedToLibrary: return "Moving into library…"
        case .databaseCommitted: return "Imported"
        case .sourceDeleted: return "Imported, source removed"
        case .skippedDuplicate: return "Skipped (duplicate)"
        case .failed: return "Failed"
        }
    }

    private func statusColor(_ status: ImportStatus) -> Color {
        switch status {
        case .failed: return .red
        case .skippedDuplicate: return .orange
        case .databaseCommitted, .sourceDeleted: return .green
        default: return .secondary
        }
    }
}
