import UIKit
enum AppForegroundCoordinator {
    static func applicationDidBecomeActive() {
        AppLogger.track(AppLogger.Event.appForeground)
        AnalyticsServices.applicationDidBecomeActive()
        guard InlineRoutingGate.isEnabled else { return }
        OfflineSurfaceCoordinator.syncWithConnectivityIfNeeded()
        flushPendingPushIfPossible()
        refreshRemoteConfigIfInlineSurfaceModeAndNeeded()
    }
    private static func flushPendingPushIfPossible() {
        guard PendingPushURLStore.hasPendingURL else { return }
        guard AppStartupSettings.resolvedMode != nil else { return }
        PushNotificationRouting.flushPendingIfPossible()
    }
    private static func refreshRemoteConfigIfInlineSurfaceModeAndNeeded() {
        guard AppStartupSettings.resolvedMode == .inlineSurface else { return }
        guard ConnectivityMonitor.shared.isOnline else { return }
        guard RemoteConfigStore.savedURLString != nil else { return }
        guard RemoteConfigStore.shouldRefreshFromEndpoint else { return }
        RemoteConfigFetchService.shared.requestConfigRefresh()
    }
}
