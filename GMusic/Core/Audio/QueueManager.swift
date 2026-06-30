import Foundation

struct QueueItem: Identifiable, Equatable {
    let id: UUID
    let trackID: UUID

    init(id: UUID = UUID(), trackID: UUID) {
        self.id = id
        self.trackID = trackID
    }
}

enum RepeatMode {
    case off
    case all
    case one
}

final class QueueManager {
    private(set) var items: [QueueItem] = []
    private(set) var currentIndex: Int?
    var repeatMode: RepeatMode = .off
    private(set) var shuffleEnabled = false

    var currentItem: QueueItem? {
        guard let currentIndex, items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    func setQueue(trackIDs: [UUID], startAt: Int = 0) {
        items = trackIDs.map { QueueItem(trackID: $0) }
        currentIndex = items.isEmpty ? nil : min(max(startAt, 0), items.count - 1)
        if shuffleEnabled {
            shuffleRemaining()
        }
    }

    func append(trackID: UUID) {
        items.append(QueueItem(trackID: trackID))
        if currentIndex == nil { currentIndex = 0 }
    }

    func remove(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        if let currentIndex {
            if index < currentIndex {
                self.currentIndex = currentIndex - 1
            } else if index == currentIndex {
                self.currentIndex = items.isEmpty ? nil : min(index, items.count - 1)
            }
        }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    @discardableResult
    func advanceToNext() -> QueueItem? {
        guard !items.isEmpty else { return nil }
        if repeatMode == .one { return currentItem }
        guard let currentIndex else {
            self.currentIndex = 0
            return currentItem
        }
        let nextIndex = currentIndex + 1
        if nextIndex < items.count {
            self.currentIndex = nextIndex
        } else if repeatMode == .all {
            self.currentIndex = 0
        } else {
            self.currentIndex = nil
        }
        return currentItem
    }

    @discardableResult
    func advanceToPrevious() -> QueueItem? {
        guard !items.isEmpty, let currentIndex else { return nil }
        let previousIndex = currentIndex - 1
        self.currentIndex = previousIndex >= 0 ? previousIndex : (repeatMode == .all ? items.count - 1 : 0)
        return currentItem
    }

    func toggleShuffle() {
        shuffleEnabled.toggle()
        if shuffleEnabled {
            shuffleRemaining()
        }
    }

    private func shuffleRemaining() {
        guard let currentIndex else {
            items.shuffle()
            return
        }
        let current = items[currentIndex]
        var rest = items
        rest.remove(at: currentIndex)
        rest.shuffle()
        items = [current] + rest
        self.currentIndex = 0
    }
}
