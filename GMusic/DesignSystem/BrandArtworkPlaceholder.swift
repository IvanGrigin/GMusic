import SwiftUI

struct BrandArtworkPlaceholder: View {
    @EnvironmentObject private var appearanceSettings: AppAppearanceSettings

    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: appearanceSettings.brandStyle.backgroundGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 72, height: 72)
                    .blur(radius: 10)
                    .offset(x: -12, y: -12)
            }
            .overlay {
                Image(systemName: appearanceSettings.noteSymbolStyle.systemImageName)
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: appearanceSettings.brandStyle.noteGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
                    .rotationEffect(.degrees(-10))
                    .offset(x: 2, y: 2)
            }
    }
}
