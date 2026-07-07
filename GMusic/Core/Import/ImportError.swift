import Foundation

enum ImportError: Error, LocalizedError {
    case unsupportedFileType
    case cannotAccessSource
    case copyFailed
    case hashMismatch
    case metadataReadFailed
    case databaseCommitFailed
    case sourceDeletionFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType: return "Unsupported file type"
        case .cannotAccessSource: return "Could not access the source file"
        case .copyFailed: return "Failed to copy the file into the library"
        case .hashMismatch: return "The copied file does not match the original"
        case .metadataReadFailed: return "Failed to read audio metadata"
        case .databaseCommitFailed: return "Failed to save the track"
        case .sourceDeletionFailed: return "Failed to delete the source file"
        }
    }
}
