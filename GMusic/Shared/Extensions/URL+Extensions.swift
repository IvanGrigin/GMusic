import Foundation

extension URL {
    var isAudioFile: Bool {
        SupportedAudioTypes.isSupported(url: self)
    }

    var fileExtensionLowercased: String {
        pathExtension.lowercased()
    }
}
