import Foundation

struct ImportScanner {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func findAudioFiles(in folderURL: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.isAudioFile {
            results.append(fileURL)
        }
        return results
    }
}
