import Foundation

private func handlePlaybackCommandNotification(
    _ center: CFNotificationCenter?,
    _ observer: UnsafeMutableRawPointer?,
    _ name: CFNotificationName?,
    _ object: UnsafeRawPointer?,
    _ userInfo: CFDictionary?
) {
    guard let observer else { return }
    let commandObserver = Unmanaged<DarwinPlaybackCommandObserver>.fromOpaque(observer).takeUnretainedValue()
    commandObserver.handleNotification()
}

final class DarwinPlaybackCommandObserver {
    private let onCommand: @Sendable () -> Void

    init(onCommand: @escaping @Sendable () -> Void) {
        self.onCommand = onCommand

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let name = WidgetSharedConstants.playbackCommandNotification as CFString

        CFNotificationCenterAddObserver(
            center,
            observer,
            handlePlaybackCommandNotification,
            name,
            nil,
            .deliverImmediately
        )
    }

    func handleNotification() {
        onCommand()
    }

    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let name = WidgetSharedConstants.playbackCommandNotification as CFString
        CFNotificationCenterRemoveObserver(center, observer, CFNotificationName(name), nil)
    }
}
