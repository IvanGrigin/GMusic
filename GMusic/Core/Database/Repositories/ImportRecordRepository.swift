import Foundation
import SwiftData

@ModelActor
actor ImportRecordRepository {
    func createRecord(_ record: ImportRecord) throws {
        modelContext.insert(record)
        try modelContext.save()
    }

    func updateRecord(id: UUID, mutate: (ImportRecord) -> Void) throws {
        guard let record = try fetchRecord(id: id) else { return }
        mutate(record)
        try modelContext.save()
    }

    func fetchRecord(id: UUID) throws -> ImportRecord? {
        var descriptor = FetchDescriptor<ImportRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func recordBySourcePath(_ path: String) throws -> ImportRecord? {
        var descriptor = FetchDescriptor<ImportRecord>(predicate: #Predicate { $0.sourceDisplayPath == path })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Imports that crashed or were interrupted before reaching a terminal status.
    func listUnfinished() throws -> [ImportRecord] {
        let descriptor = FetchDescriptor<ImportRecord>(
            predicate: #Predicate { record in
                record.status != ImportStatus.sourceDeleted &&
                record.status != ImportStatus.skippedDuplicate &&
                record.status != ImportStatus.failed
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func listFailed() throws -> [ImportRecord] {
        var descriptor = FetchDescriptor<ImportRecord>(predicate: #Predicate { $0.status == ImportStatus.failed })
        descriptor.sortBy = [SortDescriptor(\.discoveredAt, order: .reverse)]
        return try modelContext.fetch(descriptor)
    }

    func listRecentlyImported(limit: Int = 50) throws -> [ImportRecord] {
        var descriptor = FetchDescriptor<ImportRecord>(predicate: #Predicate { $0.importedAt != nil })
        descriptor.sortBy = [SortDescriptor(\.importedAt, order: .reverse)]
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }
}
