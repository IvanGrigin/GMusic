import Foundation
import SwiftData

enum TrackSortOption {
    case titleAscending
    case artistAscending
    case recentlyImported
    case mostPlayed
}

@ModelActor
actor TrackRepository {
    func createTrack(_ track: Track) throws {
        modelContext.insert(track)
        try modelContext.save()
    }

    func updateTrack(id: UUID, mutate: (Track) -> Void) throws {
        guard let track = try fetchTrack(id: id) else { return }
        mutate(track)
        try modelContext.save()
    }

    func deleteTrack(id: UUID) throws {
        guard let track = try fetchTrack(id: id) else { return }
        modelContext.delete(track)
        try modelContext.save()
    }

    func fetchTrack(id: UUID) throws -> Track? {
        var descriptor = FetchDescriptor<Track>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func track(byHash hash: String) throws -> Track? {
        var descriptor = FetchDescriptor<Track>(predicate: #Predicate { $0.fileHashSHA256 == hash })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func listAllHashes() throws -> Set<String> {
        Set(try modelContext.fetch(FetchDescriptor<Track>()).map(\.fileHashSHA256))
    }

    func listTracks(sortedBy sort: TrackSortOption = .titleAscending) throws -> [Track] {
        var descriptor = FetchDescriptor<Track>()
        switch sort {
        case .titleAscending:
            descriptor.sortBy = [SortDescriptor(\.title)]
        case .artistAscending:
            descriptor.sortBy = [SortDescriptor(\.artistName)]
        case .recentlyImported:
            descriptor.sortBy = [SortDescriptor(\.dateImported, order: .reverse)]
        case .mostPlayed:
            descriptor.sortBy = [SortDescriptor(\.playCount, order: .reverse), SortDescriptor(\.title)]
        }
        return try modelContext.fetch(descriptor)
    }

    func listTracks(albumID: UUID) throws -> [Track] {
        var descriptor = FetchDescriptor<Track>(predicate: #Predicate { $0.albumID == albumID })
        descriptor.sortBy = [SortDescriptor(\.discNumber), SortDescriptor(\.trackNumber)]
        return try modelContext.fetch(descriptor)
    }

    /// Resolves track IDs in the given order (used by playlists, where order matters).
    func listTracks(ids: [UUID]) throws -> [Track] {
        let descriptor = FetchDescriptor<Track>(predicate: #Predicate { ids.contains($0.id) })
        let tracks = try modelContext.fetch(descriptor)
        let order = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        return tracks.sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
    }

    func incrementPlayCount(id: UUID) throws {
        guard let track = try fetchTrack(id: id) else { return }
        track.playCount += 1
        track.lastPlayedAt = .now
        try modelContext.save()
    }

    @discardableResult
    func normalizeArtistCapitalizationVariants() throws -> Bool {
        let tracks = try modelContext.fetch(FetchDescriptor<Track>())
        let albums = try modelContext.fetch(FetchDescriptor<Album>())
        var changed = false

        let groupedTracks = Dictionary(grouping: tracks, by: { $0.artistName.normalizedArtistKey })
        for (key, group) in groupedTracks where Set(group.map(\.artistName)).count > 1 {
            let preferred = preferredArtistName(for: group.map(\.artistName))
            changed = applyArtistMerge(
                sourceNames: Set(group.map(\.artistName)),
                targetName: preferred,
                tracks: tracks,
                albums: albums
            ) || changed
            changed = consolidateAlbums(
                artistKey: key,
                targetArtistName: preferred,
                tracks: tracks,
                albums: albums
            ) || changed
        }

        let groupedAlbumArtists = Dictionary(grouping: tracks.compactMap(\.albumArtistName), by: \.normalizedArtistKey)
        for group in groupedAlbumArtists.values where Set(group).count > 1 {
            let preferred = preferredArtistName(for: group)
            for track in tracks where track.albumArtistName?.normalizedArtistKey == preferred.normalizedArtistKey {
                if track.albumArtistName != preferred {
                    track.albumArtistName = preferred
                    changed = true
                }
            }
        }

        if changed {
            try modelContext.save()
        }
        return changed
    }

    func listArtistSummaries() throws -> [ArtistSummary] {
        let tracks = try modelContext.fetch(FetchDescriptor<Track>())
        let groupedTracks = Dictionary(grouping: tracks, by: { $0.artistName.normalizedArtistKey })

        return groupedTracks.compactMap { normalizedKey, grouped in
            guard !grouped.isEmpty else { return nil }
            let sortedTracks = grouped.sorted {
                if $0.title == $1.title {
                    return $0.originalFileName.localizedCaseInsensitiveCompare($1.originalFileName) == .orderedAscending
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            let displayName = preferredArtistName(for: grouped.map(\.artistName))
            let alternateNames = Array(Set(grouped.map(\.artistName))).sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
            let artworkID = sortedTracks.first(where: { $0.artworkID != nil })?.artworkID
            let totalDuration = sortedTracks.reduce(0) { $0 + $1.durationSeconds }
            return ArtistSummary(
                normalizedKey: normalizedKey,
                displayName: displayName,
                alternateNames: alternateNames,
                trackIDs: sortedTracks.map(\.id),
                artworkID: artworkID,
                totalDuration: totalDuration
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func listMergeSuggestions(for artistKey: String, limit: Int = 8) throws -> [ArtistMergeSuggestion] {
        let artists = try listArtistSummaries()
        guard let source = artists.first(where: { $0.normalizedKey == artistKey }) else { return [] }

        let sourceName = source.displayName.normalizedArtistComparison
        return artists
            .filter { $0.normalizedKey != artistKey }
            .compactMap { candidate in
                let candidateName = candidate.displayName.normalizedArtistComparison
                let distance = sourceName.levenshteinDistance(to: candidateName)
                let threshold = max(1, min(sourceName.count, candidateName.count) / 3)
                guard distance <= threshold else { return nil }
                return ArtistMergeSuggestion(source: candidate, distance: distance)
            }
            .sorted {
                if $0.distance == $1.distance {
                    return $0.source.displayName.localizedCaseInsensitiveCompare($1.source.displayName) == .orderedAscending
                }
                return $0.distance < $1.distance
            }
            .prefix(limit)
            .map { $0 }
    }

    @discardableResult
    func mergeArtists(sourceNames: [String], into targetName: String) throws -> Bool {
        guard let preferredTarget = targetName.trimmedNonEmpty else { return false }
        let tracks = try modelContext.fetch(FetchDescriptor<Track>())
        let albums = try modelContext.fetch(FetchDescriptor<Album>())
        let normalizedSourceNames = Set(sourceNames.compactMap(\.trimmedNonEmpty)).subtracting([preferredTarget])
        guard !normalizedSourceNames.isEmpty else { return false }

        let changedTracksOrAlbums = applyArtistMerge(
            sourceNames: normalizedSourceNames,
            targetName: preferredTarget,
            tracks: tracks,
            albums: albums
        )

        let changedAlbumStructure = consolidateAlbums(
            artistNames: normalizedSourceNames.union([preferredTarget]),
            targetArtistName: preferredTarget,
            tracks: tracks,
            albums: albums
        )

        let changed = changedTracksOrAlbums || changedAlbumStructure
        if changed {
            try modelContext.save()
        }
        return changed
    }

    private func applyArtistMerge(
        sourceNames: Set<String>,
        targetName: String,
        tracks: [Track],
        albums: [Album]
    ) -> Bool {
        var changed = false

        for track in tracks {
            if sourceNames.contains(track.artistName), track.artistName != targetName {
                track.artistName = targetName
                changed = true
            }
            if let albumArtistName = track.albumArtistName,
               sourceNames.contains(albumArtistName),
               albumArtistName != targetName {
                track.albumArtistName = targetName
                changed = true
            }
        }

        for album in albums where sourceNames.contains(album.artistName) && album.artistName != targetName {
            album.artistName = targetName
            album.updatedAt = .now
            changed = true
        }

        return changed
    }

    private func consolidateAlbums(
        artistKey: String,
        targetArtistName: String,
        tracks: [Track],
        albums: [Album]
    ) -> Bool {
        let candidateNames = Set(albums.filter { $0.artistName.normalizedArtistKey == artistKey }.map(\.artistName))
        return consolidateAlbums(
            artistNames: candidateNames.union([targetArtistName]),
            targetArtistName: targetArtistName,
            tracks: tracks,
            albums: albums
        )
    }

    private func consolidateAlbums(
        artistNames: Set<String>,
        targetArtistName: String,
        tracks: [Track],
        albums: [Album]
    ) -> Bool {
        let candidateAlbums = albums.filter { artistNames.contains($0.artistName) || $0.artistName.normalizedArtistKey == targetArtistName.normalizedArtistKey }
        guard !candidateAlbums.isEmpty else { return false }

        var changed = false
        var canonicalAlbumsByTitle: [String: Album] = [:]

        for album in candidateAlbums.sorted(by: { $0.updatedAt < $1.updatedAt }) {
            let titleKey = album.title.normalizedArtistComparison
            if let canonicalAlbum = canonicalAlbumsByTitle[titleKey], canonicalAlbum.id != album.id {
                for track in tracks where track.albumID == album.id {
                    track.albumID = canonicalAlbum.id
                    changed = true
                }
                if canonicalAlbum.artworkID == nil, album.artworkID != nil {
                    canonicalAlbum.artworkID = album.artworkID
                    changed = true
                }
                canonicalAlbum.updatedAt = .now
                modelContext.delete(album)
                changed = true
            } else {
                canonicalAlbumsByTitle[titleKey] = album
                if album.artistName != targetArtistName {
                    album.artistName = targetArtistName
                    album.updatedAt = .now
                    changed = true
                }
            }
        }

        return changed
    }

    private func preferredArtistName(for names: [String]) -> String {
        let groupedNames = Dictionary(grouping: names, by: { $0.collapsedWhitespace.trimmingCharacters(in: .whitespacesAndNewlines) })
        return groupedNames
            .map { name, variants in
                let frequency = variants.count
                let lowercase = name.lowercased()
                let uppercase = name.uppercased()
                let styleScore: Int
                if name == lowercase {
                    styleScore = 0
                } else if name == uppercase, name.count > 2 {
                    styleScore = 1
                } else {
                    styleScore = 2
                }
                return (name: name, frequency: frequency, styleScore: styleScore)
            }
            .sorted {
                if $0.frequency == $1.frequency {
                    if $0.styleScore == $1.styleScore {
                        if $0.name.count == $1.name.count {
                            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                        }
                        return $0.name.count > $1.name.count
                    }
                    return $0.styleScore > $1.styleScore
                }
                return $0.frequency > $1.frequency
            }
            .first?.name ?? "Unknown Artist"
    }
}
