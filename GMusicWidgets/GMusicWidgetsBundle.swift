import SwiftUI
import WidgetKit

@main
struct GMusicWidgetsBundle: WidgetBundle {
    var body: some Widget {
        GMusicNowPlayingWidget()
        GMusicPlaybackLiveActivityWidget()
    }
}
