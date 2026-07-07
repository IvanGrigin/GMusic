import ActivityKit
import Foundation

@MainActor
final class NowPlayingLiveActivityManager {
    private var activity: Activity<PlaybackActivityAttributes>?

    func startOrUpdate(with snapshot: NowPlayingWidgetSnapshot) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = PlaybackActivityAttributes(trackID: snapshot.trackID)
        let contentState = PlaybackActivityAttributes.ContentState(
            title: snapshot.title,
            artist: snapshot.artist,
            isPlaying: snapshot.isPlaying,
            elapsedTime: snapshot.elapsedTime,
            duration: snapshot.duration,
            artworkFileName: snapshot.artworkFileName
        )
        let content = ActivityContent(state: contentState, staleDate: nil)

        if let activity, activity.attributes.trackID == snapshot.trackID {
            await activity.update(content)
            return
        }

        if let activity {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        do {
            activity = try Activity.request(attributes: attributes, content: content)
        } catch {
            activity = nil
        }
    }

    func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
