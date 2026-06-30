import SwiftUI
import UIKit

struct ArtworkView: View {
    let imageURL: URL?
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let imageURL, let uiImage = UIImage(contentsOfFile: imageURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle().fill(Color.secondary.opacity(0.2))
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
