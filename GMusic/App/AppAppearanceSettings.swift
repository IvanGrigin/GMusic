import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppBrandStyle: String, CaseIterable, Identifiable {
    case citrus
    case ember
    case graphite
    case ocean
    case forest
    case berry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .citrus: "Citrus"
        case .ember: "Ember"
        case .graphite: "Graphite"
        case .ocean: "Ocean"
        case .forest: "Forest"
        case .berry: "Berry"
        }
    }

    var accentColor: Color {
        switch self {
        case .citrus: Color(red: 0.98, green: 0.47, blue: 0.12)
        case .ember: Color(red: 0.88, green: 0.29, blue: 0.14)
        case .graphite: Color(red: 0.48, green: 0.50, blue: 0.54)
        case .ocean: Color(red: 0.10, green: 0.58, blue: 0.86)
        case .forest: Color(red: 0.18, green: 0.58, blue: 0.35)
        case .berry: Color(red: 0.82, green: 0.22, blue: 0.45)
        }
    }

    var backgroundGradient: [Color] {
        switch self {
        case .citrus:
            [
                Color(red: 1.00, green: 0.72, blue: 0.36),
                Color(red: 0.98, green: 0.47, blue: 0.12),
                Color(red: 0.78, green: 0.18, blue: 0.08),
            ]
        case .ember:
            [
                Color(red: 1.00, green: 0.62, blue: 0.32),
                Color(red: 0.90, green: 0.23, blue: 0.11),
                Color(red: 0.41, green: 0.05, blue: 0.05),
            ]
        case .graphite:
            [
                Color(red: 0.34, green: 0.34, blue: 0.37),
                Color(red: 0.12, green: 0.12, blue: 0.14),
                Color.black,
            ]
        case .ocean:
            [
                Color(red: 0.52, green: 0.86, blue: 1.00),
                Color(red: 0.10, green: 0.58, blue: 0.86),
                Color(red: 0.03, green: 0.18, blue: 0.42),
            ]
        case .forest:
            [
                Color(red: 0.69, green: 0.93, blue: 0.74),
                Color(red: 0.18, green: 0.58, blue: 0.35),
                Color(red: 0.05, green: 0.20, blue: 0.11),
            ]
        case .berry:
            [
                Color(red: 1.00, green: 0.72, blue: 0.84),
                Color(red: 0.82, green: 0.22, blue: 0.45),
                Color(red: 0.31, green: 0.04, blue: 0.18),
            ]
        }
    }

    var noteGradient: [Color] {
        switch self {
        case .citrus, .ember, .ocean, .forest, .berry:
            [
                Color.white.opacity(0.96),
                Color(red: 0.98, green: 0.98, blue: 0.99),
                Color.white.opacity(0.78),
            ]
        case .graphite:
            [
                Color.white,
                Color(red: 0.86, green: 0.87, blue: 0.90),
                Color(red: 0.70, green: 0.72, blue: 0.76),
            ]
        }
    }

    var alternateIconName: String? {
        switch self {
        case .citrus: nil
        case .ember: "AppIconEmber"
        case .graphite: "AppIconGraphite"
        case .ocean: "AppIconOcean"
        case .forest: "AppIconForest"
        case .berry: "AppIconBerry"
        }
    }
}

enum AppNoteSymbolStyle: String, CaseIterable, Identifiable {
    case classic
    case list
    case chorus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic"
        case .list: "Playlist"
        case .chorus: "Chorus"
        }
    }

    var systemImageName: String {
        switch self {
        case .classic: "music.note"
        case .list: "music.note.list"
        case .chorus: "music.quarternote.3"
        }
    }
}

@MainActor
final class AppAppearanceSettings: ObservableObject {
    @Published var theme: AppTheme
    @Published var brandStyle: AppBrandStyle
    @Published var noteSymbolStyle: AppNoteSymbolStyle

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        brandStyle = AppBrandStyle(rawValue: defaults.string(forKey: Keys.brandStyle) ?? "") ?? .citrus
        noteSymbolStyle = AppNoteSymbolStyle(rawValue: defaults.string(forKey: Keys.noteSymbolStyle) ?? "") ?? .classic
    }

    var preferredColorScheme: ColorScheme? {
        theme.colorScheme
    }

    var tintColor: Color {
        brandStyle.accentColor
    }

    func setTheme(_ theme: AppTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        defaults.set(theme.rawValue, forKey: Keys.theme)
    }

    func setBrandStyle(_ brandStyle: AppBrandStyle) async {
        guard self.brandStyle != brandStyle else { return }
        self.brandStyle = brandStyle
        defaults.set(brandStyle.rawValue, forKey: Keys.brandStyle)
        await applyAppIcon()
    }

    func setNoteSymbolStyle(_ noteSymbolStyle: AppNoteSymbolStyle) {
        guard self.noteSymbolStyle != noteSymbolStyle else { return }
        self.noteSymbolStyle = noteSymbolStyle
        defaults.set(noteSymbolStyle.rawValue, forKey: Keys.noteSymbolStyle)
    }

    func applyAppIcon() async {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let iconName = brandStyle.alternateIconName
        guard UIApplication.shared.alternateIconName != iconName else { return }
        await withCheckedContinuation { continuation in
            UIApplication.shared.setAlternateIconName(iconName) { _ in
                continuation.resume()
            }
        }
    }

    private enum Keys {
        static let theme = "appearance.theme"
        static let brandStyle = "appearance.brandStyle"
        static let noteSymbolStyle = "appearance.noteSymbolStyle"
    }
}
