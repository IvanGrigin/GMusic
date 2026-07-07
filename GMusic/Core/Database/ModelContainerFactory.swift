import Foundation
import SwiftData

enum ModelContainerFactory {
    private static var schema: Schema {
        Schema([Track.self, Album.self, Playlist.self, Artwork.self, ImportRecord.self])
    }

    static func makeContainer(storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
