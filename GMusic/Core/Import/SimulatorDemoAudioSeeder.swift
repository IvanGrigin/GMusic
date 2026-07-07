import Foundation

/// Creates short audio files inside the app's Documents directory so simulator
/// builds always have something real to import without manual setup.
final class SimulatorDemoAudioSeeder {
    struct DemoFolderSummary {
        let totalAudioFiles: Int
        let uniqueTrackCount: Int
        let duplicateFileCount: Int
        let folderCount: Int
        let structurePreview: [String]
    }

    private struct DemoTrack {
        let durationSeconds: Double
        let progression: [[Double]]
        let bassFrequency: Double
    }

    private enum DemoFileKind {
        case generated(DemoTrack)
        case exactDuplicate(ofRelativePath: String)
    }

    private struct DemoFile {
        let relativePath: String
        let kind: DemoFileKind
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var isAvailable: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    var demoFolderName: String { "GMusic Demo Imports" }
    var duplicateCleanupFolderName: String { "04 Duplicates To Clean" }

    func demoFolderURL() throws -> URL? {
        guard isAvailable else { return nil }
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documentsURL.appendingPathComponent(demoFolderName, isDirectory: true)
    }

    func duplicateCleanupFolderURL() throws -> URL? {
        guard let rootURL = try demoFolderURL() else { return nil }
        return rootURL.appendingPathComponent(duplicateCleanupFolderName, isDirectory: true)
    }

    @discardableResult
    func prepareDemoFilesIfNeeded(forceRewrite: Bool = false) throws -> URL? {
        guard let folderURL = try demoFolderURL() else { return nil }
        if !fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        for file in demoFiles {
            let fileURL = folderURL.appendingPathComponent(file.relativePath)
            let folderForFile = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: folderForFile.path) {
                try fileManager.createDirectory(at: folderForFile, withIntermediateDirectories: true)
            }
            if forceRewrite, fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            if !fileManager.fileExists(atPath: fileURL.path) {
                switch file.kind {
                case .generated(let track):
                    try makeWaveFileData(track: track).write(to: fileURL, options: .atomic)
                case .exactDuplicate(let sourceRelativePath):
                    let sourceURL = folderURL.appendingPathComponent(sourceRelativePath)
                    try fileManager.copyItem(at: sourceURL, to: fileURL)
                }
            }
        }

        return folderURL
    }

    func demoAudioURLs() throws -> [URL] {
        guard let folderURL = try prepareDemoFilesIfNeeded() else { return [] }
        return demoFiles
            .map { folderURL.appendingPathComponent($0.relativePath) }
            .filter { fileManager.fileExists(atPath: $0.path) }
    }

    func demoFolderSummary() throws -> DemoFolderSummary {
        let folderCount = Set(demoFiles.map { relativeFolderPath(for: $0.relativePath) }).count
        let duplicateCount = demoFiles.reduce(into: 0) { result, file in
            if case .exactDuplicate = file.kind {
                result += 1
            }
        }

        return DemoFolderSummary(
            totalAudioFiles: demoFiles.count,
            uniqueTrackCount: demoFiles.count - duplicateCount,
            duplicateFileCount: duplicateCount,
            folderCount: folderCount,
            structurePreview: [
                "01 Quick File Imports",
                "02 Album Folders/Aurora Sessions/Disc 1",
                "02 Album Folders/Aurora Sessions/Disc 2",
                "03 Mixed Sources/Live Sets/2026 Opening",
                "04 Duplicates To Clean/Shared/Subfolder"
            ]
        )
    }

    private var demoFiles: [DemoFile] {
        [
            DemoFile(
                relativePath: "01 Quick File Imports/01 - Aurora Ensemble - Northern Lights.wav",
                kind: .generated(
                    DemoTrack(
                        durationSeconds: 12,
                        progression: [
                            [261.63, 329.63, 392.00],
                            [293.66, 369.99, 440.00],
                            [329.63, 415.30, 493.88],
                            [293.66, 349.23, 440.00],
                        ],
                        bassFrequency: 130.81
                    )
                )
            ),
            DemoFile(
                relativePath: "01 Quick File Imports/02 - Aurora Ensemble - Glass Streets.wav",
                kind: .generated(
                    DemoTrack(
                        durationSeconds: 14,
                        progression: [
                            [220.00, 277.18, 329.63],
                            [246.94, 311.13, 369.99],
                            [261.63, 329.63, 392.00],
                            [233.08, 293.66, 349.23],
                        ],
                        bassFrequency: 110.00
                    )
                )
            ),
            DemoFile(
                relativePath: "02 Album Folders/Aurora Sessions/Disc 1/01 - Aurora Ensemble - Sunrise Circuit.wav",
                kind: .generated(
                    DemoTrack(
                        durationSeconds: 16,
                        progression: [
                            [174.61, 233.08, 293.66],
                            [196.00, 246.94, 329.63],
                            [220.00, 277.18, 349.23],
                            [196.00, 261.63, 329.63],
                        ],
                        bassFrequency: 98.00
                    )
                )
            ),
            DemoFile(
                relativePath: "02 Album Folders/Aurora Sessions/Disc 1/02 - Aurora Ensemble - Neon Harbor.wav",
                kind: .generated(
                    DemoTrack(
                        durationSeconds: 15,
                        progression: [
                            [185.00, 233.08, 311.13],
                            [207.65, 261.63, 329.63],
                            [233.08, 293.66, 369.99],
                            [207.65, 261.63, 349.23],
                        ],
                        bassFrequency: 92.50
                    )
                )
            ),
            DemoFile(
                relativePath: "02 Album Folders/Aurora Sessions/Disc 2/01 - AURORA ENSEMBLE - Northern Lights Copy.wav",
                kind: .exactDuplicate(ofRelativePath: "01 Quick File Imports/01 - Aurora Ensemble - Northern Lights.wav")
            ),
            DemoFile(
                relativePath: "03 Mixed Sources/Live Sets/2026 Opening/01 - Echo Bloom - Tidal Signal.wav",
                kind: .generated(
                    DemoTrack(
                        durationSeconds: 13,
                        progression: [
                            [246.94, 311.13, 392.00],
                            [261.63, 329.63, 415.30],
                            [220.00, 293.66, 369.99],
                            [196.00, 277.18, 349.23],
                        ],
                        bassFrequency: 123.47
                    )
                )
            ),
            DemoFile(
                relativePath: "03 Mixed Sources/Live Sets/2026 Opening/Copies/01 - Echo Bloom - Tidal Signal Copy.wav",
                kind: .exactDuplicate(ofRelativePath: "03 Mixed Sources/Live Sets/2026 Opening/01 - Echo Bloom - Tidal Signal.wav")
            ),
            DemoFile(
                relativePath: "04 Duplicates To Clean/Phone Drops/02 - Aurora Ensemble - Glass Streets Duplicate.wav",
                kind: .exactDuplicate(ofRelativePath: "01 Quick File Imports/02 - Aurora Ensemble - Glass Streets.wav")
            ),
            DemoFile(
                relativePath: "04 Duplicates To Clean/Shared/Subfolder/03 - Aurora Ensemble - Sunrise Circuit Duplicate.wav",
                kind: .exactDuplicate(ofRelativePath: "02 Album Folders/Aurora Sessions/Disc 1/01 - Aurora Ensemble - Sunrise Circuit.wav")
            ),
        ]
    }

    private func makeWaveFileData(track: DemoTrack) -> Data {
        let sampleRate = 44_100
        let bitsPerSample = 16
        let channelCount = 1
        let sampleCount = Int(track.durationSeconds * Double(sampleRate))
        let bytesPerFrame = channelCount * (bitsPerSample / 8)
        let dataSize = sampleCount * bytesPerFrame

        var data = Data(capacity: 44 + dataSize)
        data.append(contentsOf: "RIFF".utf8)
        data.appendLittleEndian(UInt32(36 + dataSize))
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(channelCount))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * bytesPerFrame))
        data.appendLittleEndian(UInt16(bytesPerFrame))
        data.appendLittleEndian(UInt16(bitsPerSample))
        data.append(contentsOf: "data".utf8)
        data.appendLittleEndian(UInt32(dataSize))

        let sectionLength = track.durationSeconds / Double(track.progression.count)
        for sampleIndex in 0 ..< sampleCount {
            let time = Double(sampleIndex) / Double(sampleRate)
            let sectionIndex = min(Int(time / sectionLength), track.progression.count - 1)
            let chord = track.progression[sectionIndex]
            let leadFrequency = chord[(sampleIndex / 11_025) % chord.count] * 2

            var sampleValue = 0.0
            for (index, frequency) in chord.enumerated() {
                sampleValue += sin(2 * .pi * frequency * time) * (0.18 / Double(index + 1))
            }
            sampleValue += sin(2 * .pi * leadFrequency * time) * 0.14
            sampleValue += sin(2 * .pi * track.bassFrequency * time) * 0.10

            let attack = min(time / 0.4, 1)
            let release = min((track.durationSeconds - time) / 0.8, 1)
            let envelope = max(0, min(attack, release))
            let normalized = max(-1, min(1, sampleValue * envelope))
            let pcmValue = Int16(normalized * Double(Int16.max) * 0.85)
            data.appendLittleEndian(pcmValue)
        }

        return data
    }

    private func relativeFolderPath(for relativePath: String) -> String {
        let nsPath = relativePath as NSString
        return nsPath.deletingLastPathComponent
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
