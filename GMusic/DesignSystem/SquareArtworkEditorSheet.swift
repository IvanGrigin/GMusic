import SwiftUI
import UIKit

enum SquareArtworkMode: String, CaseIterable, Identifiable {
    case crop
    case fitBlack
    case fitWhite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crop: "Crop"
        case .fitBlack: "Black Matte"
        case .fitWhite: "White Matte"
        }
    }

    var canvasColor: UIColor {
        switch self {
        case .crop, .fitWhite: .white
        case .fitBlack: .black
        }
    }
}

private enum SquareArtworkPlacement: String, CaseIterable, Identifiable {
    case top
    case center
    case bottom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top: "Top"
        case .center: "Center"
        case .bottom: "Bottom"
        }
    }
}

struct ArtworkDraft: Identifiable {
    let id = UUID()
    let imageData: Data
}

struct SquareArtworkEditorSheet: View {
    private let previewSide: CGFloat = 280
    private let exportSide: CGFloat = 1400

    let title: String
    let sourceImage: UIImage?
    let onSave: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: SquareArtworkMode = .crop
    @State private var zoom: CGFloat = 1
    @State private var committedOffset: CGSize = .zero
    @State private var placement: SquareArtworkPlacement = .center
    @GestureState private var dragOffset: CGSize = .zero

    init(imageData: Data, title: String = "Adjust Artwork", onSave: @escaping (Data) -> Void) {
        self.title = title
        self.onSave = onSave
        sourceImage = UIImage(data: imageData)?.normalizedOrientation()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                preview

                Form {
                    Section("Artwork Style") {
                        Picker("Mode", selection: $mode) {
                            ForEach(SquareArtworkMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if mode == .crop {
                        Section("Crop") {
                            LabeledContent("Zoom") {
                                Text(String(format: "%.2fx", zoom))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $zoom, in: 1...3, step: 0.01)
                                .onChange(of: zoom) { _, newValue in
                                    committedOffset = clampedOffset(committedOffset, zoom: newValue, side: previewSide)
                                }
                            Text("Drag the image to choose the square crop.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("Matte Placement") {
                            Picker("Placement", selection: $placement) {
                                ForEach(SquareArtworkPlacement.allCases) { placement in
                                    Text(placement.title).tag(placement)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text("Use Top placement to keep the photo high and leave extra field below.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Artwork") {
                        guard let data = renderedJPEGData() else { return }
                        onSave(data)
                        dismiss()
                    }
                    .disabled(sourceImage == nil)
                }
            }
            .background(AppColors.background)
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: mode.canvasColor))
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 10)

            if let sourceImage {
                if mode == .crop {
                    let imageSize = cropDisplaySize(for: previewSide, zoom: zoom, imageSize: sourceImage.size)
                    let offset = clampedOffset(
                        CGSize(
                            width: committedOffset.width + dragOffset.width,
                            height: committedOffset.height + dragOffset.height
                        ),
                        zoom: zoom,
                        side: previewSide
                    )

                    Image(uiImage: sourceImage)
                        .resizable()
                        .frame(width: imageSize.width, height: imageSize.height)
                        .offset(offset)
                        .gesture(cropGesture)
                } else {
                    let imageSize = fitDisplaySize(for: previewSide, imageSize: sourceImage.size)
                    let origin = fitOrigin(for: previewSide, imageSize: imageSize, placement: placement)

                    Image(uiImage: sourceImage)
                        .resizable()
                        .frame(width: imageSize.width, height: imageSize.height)
                        .position(
                            x: origin.x + (imageSize.width / 2),
                            y: origin.y + (imageSize.height / 2)
                        )
                }
            } else {
                ContentUnavailableView("Invalid Image", systemImage: "photo.badge.exclamationmark")
            }
        }
        .frame(width: previewSide, height: previewSide)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.top, 8)
    }

    private var cropGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                committedOffset = clampedOffset(
                    CGSize(
                        width: committedOffset.width + value.translation.width,
                        height: committedOffset.height + value.translation.height
                    ),
                    zoom: zoom,
                    side: previewSide
                )
            }
    }

    private func cropDisplaySize(for side: CGFloat, zoom: CGFloat, imageSize: CGSize) -> CGSize {
        let width = max(imageSize.width, 1)
        let height = max(imageSize.height, 1)
        let baseScale = max(side / width, side / height)
        return CGSize(width: width * baseScale * zoom, height: height * baseScale * zoom)
    }

    private func fitDisplaySize(for side: CGFloat, imageSize: CGSize) -> CGSize {
        let width = max(imageSize.width, 1)
        let height = max(imageSize.height, 1)
        let baseScale = min(side / width, side / height)
        return CGSize(width: width * baseScale, height: height * baseScale)
    }

    private func clampedOffset(_ offset: CGSize, zoom: CGFloat, side: CGFloat) -> CGSize {
        guard let sourceImage else { return .zero }
        let size = cropDisplaySize(for: side, zoom: zoom, imageSize: sourceImage.size)
        let maxX = max(0, (size.width - side) / 2)
        let maxY = max(0, (size.height - side) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private func fitOrigin(for side: CGFloat, imageSize: CGSize, placement: SquareArtworkPlacement) -> CGPoint {
        let x = (side - imageSize.width) / 2
        let remainingY = max(0, side - imageSize.height)
        let y: CGFloat
        switch placement {
        case .top:
            y = 0
        case .center:
            y = remainingY / 2
        case .bottom:
            y = remainingY
        }
        return CGPoint(x: x, y: y)
    }

    private func renderedJPEGData() -> Data? {
        guard let sourceImage else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: exportSide, height: exportSide),
            format: format
        )

        let image = renderer.image { context in
            let bounds = CGRect(x: 0, y: 0, width: exportSide, height: exportSide)
            mode.canvasColor.setFill()
            context.fill(bounds)

            switch mode {
            case .crop:
                let imageSize = cropDisplaySize(for: exportSide, zoom: zoom, imageSize: sourceImage.size)
                let previewOffset = clampedOffset(committedOffset, zoom: zoom, side: previewSide)
                let scaledOffset = CGSize(
                    width: (previewOffset.width / previewSide) * exportSide,
                    height: (previewOffset.height / previewSide) * exportSide
                )
                let rect = CGRect(
                    x: ((exportSide - imageSize.width) / 2) + scaledOffset.width,
                    y: ((exportSide - imageSize.height) / 2) + scaledOffset.height,
                    width: imageSize.width,
                    height: imageSize.height
                )
                sourceImage.draw(in: rect)

            case .fitBlack, .fitWhite:
                let imageSize = fitDisplaySize(for: exportSide, imageSize: sourceImage.size)
                let origin = fitOrigin(for: exportSide, imageSize: imageSize, placement: placement)
                sourceImage.draw(in: CGRect(origin: origin, size: imageSize))
            }
        }

        return image.jpegData(compressionQuality: 0.94)
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
