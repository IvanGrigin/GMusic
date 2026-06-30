import SwiftUI
import UniformTypeIdentifiers

struct ImportInboxView: View {
    @StateObject private var viewModel: ImportInboxViewModel
    @State private var isPickingFiles = false
    @State private var isPickingFolder = false

    init(appEnvironment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: ImportInboxViewModel(
            importPipeline: appEnvironment.importPipeline,
            importRecordRepository: appEnvironment.importRecordRepository,
            importScanner: appEnvironment.importScanner,
            folderBookmarkStore: appEnvironment.folderBookmarkStore
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isPickingFiles = true
                    } label: {
                        Label("Import Files", systemImage: "doc.badge.plus")
                    }
                    .disabled(viewModel.isImporting)

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
                            Text("Importing…")
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
