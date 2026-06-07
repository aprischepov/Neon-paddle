import UIKit

enum AppForegroundCoordinator {
    static func applicationDidBecomeActive() {
        AppLogger.track(AppLogger.Event.appForeground)
        AnalyticsServices.applicationDidBecomeActive()
        guard GrayFlowGate.isEnabled else { return }
        WebViewOfflineRootCoordinator.syncWithConnectivityIfNeeded()
        flushPendingPushIfPossible()
        refreshRemoteConfigIfWebViewModeAndNeeded()
    }

    private static func flushPendingPushIfPossible() {
        guard PendingPushURLStore.hasPendingURL else { return }
        guard AppStartupSettings.resolvedMode != nil else { return }
        PushNotificationRouting.flushPendingIfPossible()
    }

    private static func refreshRemoteConfigIfWebViewModeAndNeeded() {
        guard AppStartupSettings.resolvedMode == .webView else { return }
        guard ConnectivityMonitor.shared.isOnline else { return }
        guard RemoteConfigStore.savedURLString != nil else { return }
        guard RemoteConfigStore.shouldRefreshFromEndpoint else { return }
        RemoteConfigFetchService.shared.requestConfigRefresh()
    }
}
