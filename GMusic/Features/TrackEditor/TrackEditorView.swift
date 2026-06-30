import SwiftUI
import PhotosUI

struct TrackEditorView: View {
    @StateObject private var viewModel: TrackEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    let onSaved: () -> Void

    init(appEnvironment: AppEnvironment, track: Track, onSaved: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: TrackEditorViewModel(
            track: track,
            trackRepository: appEnvironment.trackRepository,
            albumRepository: appEnvironment.albumRepository,
            artworkFileStore: appEnvironment.artworkFileStore
        ))
        self.onSaved = onSaved
        self.appEnvironment = appEnvironment
    }

    let appEnvironment: AppEnvironment

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ArtworkView(imageURL: viewModel.artworkID.map { appEnvironment.artworkFileStore.url(forArtworkID: $0) })
                            .frame(width: 120, height: 120)
                        Spacer()
                    }
                    PhotosPicker("Choose Artwork", selection: $photoItem, matching: .images)
                }

                Section("Metadata") {
                    TextField("Title", text: $viewModel.title)
                    TextField("Artist", text: $viewModel.artistName)
                    TextField("Album", text: $viewModel.albumTitle)
                    TextField("Genre", text: $viewModel.genre)
                    TextField("Year", text: $viewModel.yearText).keyboardType(.numberPad)
                    TextField("Track Number", text: $viewModel.trackNumberText).keyboardType(.numberPad)
                }

                Section("Lyrics") {
                    TextEditor(text: $viewModel.lyrics).frame(minHeight: 120)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Track")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .onChange(of: photoItem) { _, newValue in
                Task {
                    if let newValue, let data = try? await newValue.loadTransferable(type: Data.self) {
                        viewModel.setArtwork(imageData: data)
                    }
                }
            }
        }
    }
}
