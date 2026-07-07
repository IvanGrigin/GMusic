import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct GMusicWidgetEntry: TimelineEntry {
    let date: Date
    let nowPlaying: NowPlayingWidgetSnapshot?
    let library: LibraryWidgetSnapshot?
}

struct GMusicWidgetProvider: TimelineProvider {
    private let sharedStore = WidgetSharedStore()

    func placeholder(in context: Context) -> GMusicWidgetEntry {
        GMusicWidgetEntry(
            date: .now,
            nowPlaying: NowPlayingWidgetSnapshot(
                trackID: UUID().uuidString,
                title: "Sunrise Circuit",
                artist: "Aurora Ensemble",
                isPlaying: true,
                elapsedTime: 42,
                duration: 188,
                artworkFileName: nil,
                updatedAt: .now
            ),
            library: LibraryWidgetSnapshot(
                trackCount: 128,
                albumCount: 19,
                playlistCount: 8,
                artistCount: 24,
                latestTrackTitle: "Sunrise Circuit",
                latestArtistName: "Aurora Ensemble",
                updatedAt: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (GMusicWidgetEntry) -> Void) {
        completion(
            GMusicWidgetEntry(
                date: .now,
                nowPlaying: sharedStore.loadNowPlaying(),
                library: sharedStore.loadLibrarySnapshot()
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GMusicWidgetEntry>) -> Void) {
        let entry = GMusicWidgetEntry(
            date: .now,
            nowPlaying: sharedStore.loadNowPlaying(),
            library: sharedStore.loadLibrarySnapshot()
        )
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 15))))
    }
}

struct GMusicNowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GMusicNowPlayingWidget", provider: GMusicWidgetProvider()) { entry in
            GMusicWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("GMusic")
        .description("Shows the current track and quick playback controls.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct GMusicWidgetView: View {
    let entry: GMusicWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            accessoryInlineLayout
        case .accessoryCircular:
            accessoryCircularLayout
        case .accessoryRectangular:
            accessoryRectangularLayout
        case .systemMedium:
            mediumLayout
        default:
            smallLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetArtwork
                .frame(maxWidth: .infinity)
                .frame(height: 92)

            if let nowPlaying = entry.nowPlaying {
                Text(nowPlaying.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(nowPlaying.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Library")
                    .font(.headline)
                Text("\(entry.library?.trackCount ?? 0) tracks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 14) {
            widgetArtwork
                .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 10) {
                if let nowPlaying = entry.nowPlaying {
                    Text(nowPlaying.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(nowPlaying.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        Button(intent: PlaybackControlIntent(command: .previous)) {
                            Image(systemName: "backward.fill")
                        }
                        Button(intent: PlaybackControlIntent(command: .playPause)) {
                            Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                        }
                        Button(intent: PlaybackControlIntent(command: .next)) {
                            Image(systemName: "forward.fill")
                        }
                    }
                    .font(.title3)
                    .buttonStyle(.borderless)
                }

                Spacer()

                if let library = entry.library {
                    HStack(spacing: 10) {
                        Label("\(library.trackCount)", systemImage: "music.note")
                        Label("\(library.playlistCount)", systemImage: "music.note.list")
                        Label("\(library.artistCount)", systemImage: "person.2")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var accessoryInlineLayout: some View {
        Group {
            if let nowPlaying = entry.nowPlaying {
                Text("\(nowPlaying.title) • \(nowPlaying.artist)")
            } else {
                Text("GMusic • \(entry.library?.trackCount ?? 0) tracks")
            }
        }
    }

    private var accessoryCircularLayout: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let image = sharedArtworkImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: entry.nowPlaying?.isPlaying == true ? "pause.fill" : "music.note")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .clipShape(ContainerRelativeShape())
    }

    private var accessoryRectangularLayout: some View {
        HStack(spacing: 10) {
            widgetArtwork
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                if let nowPlaying = entry.nowPlaying {
                    Text(nowPlaying.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(nowPlaying.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("GMusic")
                        .font(.headline)
                    Text("\(entry.library?.trackCount ?? 0) tracks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var widgetArtwork: some View {
        if let image = sharedArtworkImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.72, blue: 0.36),
                            Color(red: 0.98, green: 0.47, blue: 0.12),
                            Color(red: 0.78, green: 0.18, blue: 0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
        }
    }

    private func sharedArtworkImage() -> UIImage? {
        guard let fileName = entry.nowPlaying?.artworkFileName,
              let url = WidgetSharedStore().sharedArtworkURL(fileName: fileName) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}

private struct AccessoryWidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.72, blue: 0.36),
                Color(red: 0.98, green: 0.47, blue: 0.12),
                Color(red: 0.78, green: 0.18, blue: 0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct GMusicPlaybackLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlaybackActivityAttributes.self) { context in
            LockScreenPlaybackView(state: context.state)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandArtworkView(fileName: context.state.artworkFileName)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 8) {
                        Button(intent: PlaybackControlIntent(command: .previous)) {
                            Image(systemName: "backward.fill")
                        }
                        Button(intent: PlaybackControlIntent(command: .playPause)) {
                            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        }
                        Button(intent: PlaybackControlIntent(command: .next)) {
                            Image(systemName: "forward.fill")
                        }
                    }
                    .buttonStyle(.borderless)
                }
            } compactLeading: {
                DynamicIslandArtworkView(fileName: context.state.artworkFileName)
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.caption.bold())
            } minimal: {
                DynamicIslandArtworkView(fileName: context.state.artworkFileName)
            }
        }
    }
}

private struct LockScreenPlaybackView: View {
    let state: PlaybackActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            DynamicIslandArtworkView(fileName: state.artworkFileName)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(state.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 12) {
                Button(intent: PlaybackControlIntent(command: .previous)) {
                    Image(systemName: "backward.fill")
                }
                Button(intent: PlaybackControlIntent(command: .playPause)) {
                    Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                }
                Button(intent: PlaybackControlIntent(command: .next)) {
                    Image(systemName: "forward.fill")
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct DynamicIslandArtworkView: View {
    let fileName: String?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.72, blue: 0.36),
                                Color(red: 0.98, green: 0.47, blue: 0.12),
                                Color(red: 0.78, green: 0.18, blue: 0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.white.opacity(0.92))
                    }
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var image: UIImage? {
        guard let fileName,
              let url = WidgetSharedStore().sharedArtworkURL(fileName: fileName) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
