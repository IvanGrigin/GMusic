import AppIntents
import WidgetKit

enum PlaybackControlChoice: String, AppEnum {
    case previous
    case playPause
    case next

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Playback Control")
    static var caseDisplayRepresentations: [PlaybackControlChoice: DisplayRepresentation] = [
        .previous: DisplayRepresentation(title: "Previous"),
        .playPause: DisplayRepresentation(title: "Play/Pause"),
        .next: DisplayRepresentation(title: "Next"),
    ]
}

struct PlaybackControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Playback Control"

    @Parameter(title: "Command")
    var command: PlaybackControlChoice

    init() {}

    init(command: PlaybackControlChoice) {
        self.command = command
    }

    func perform() async throws -> some IntentResult {
        let sharedStore = WidgetSharedStore()
        switch command {
        case .previous:
            sharedStore.sendPlaybackCommand(.previous)
        case .playPause:
            sharedStore.sendPlaybackCommand(.playPause)
        case .next:
            sharedStore.sendPlaybackCommand(.next)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
