import SwiftUI
import UIKit

@MainActor
final class ArtworkImageCache {
    static let shared = ArtworkImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

struct ArtworkView: View {
    let imageURL: URL?
    var cornerRadius: CGFloat = 8

    @State private var loadedImage: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    BrandArtworkPlaceholder(cornerRadius: cornerRadius)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .task(id: imageURL) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let imageURL else {
            loadedImage = nil
            return
        }
        if let cached = ArtworkImageCache.shared.image(for: imageURL) {
            loadedImage = cached
            return
        }
        let image = await Task.detached(priority: .userInitiated) {
            UIImage(contentsOfFile: imageURL.path)
        }.value
        guard let image, !Task.isCancelled else { return }
        ArtworkImageCache.shared.store(image, for: imageURL)
        loadedImage = image
    }
}
