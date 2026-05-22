import UIKit

/// Логика при уходе приложения на передний план.
enum AppForegroundCoordinator {
    static func applicationDidBecomeActive() {
        AnalyticsServices.applicationDidBecomeActive()
        WebViewOfflineRootCoordinator.syncWithConnectivityIfNeeded()
        flushPendingPushIfPossible()
        refreshRemoteConfigIfWebViewModeAndNeeded()
    }

    private static func flushPendingPushIfPossible() {
        print("[PUSH][foreground] flushPendingPushIfPossible hasPending=\(PendingPushURLStore.hasPendingURL) resolvedMode=\(String(describing: AppStartupSettings.resolvedMode))")
        guard PendingPushURLStore.hasPendingURL else { return }
        guard AppStartupSettings.resolvedMode != nil else { return }
        PushNotificationRouting.flushPendingIfPossible()
    }

    /// П. 2.1: при активном WebView-режиме и сети — обновить конфиг по `expires` (контракт конфига).
    private static func refreshRemoteConfigIfWebViewModeAndNeeded() {
        guard AppStartupSettings.resolvedMode == .webView else { return }
        guard ConnectivityMonitor.shared.isOnline else { return }
        guard RemoteConfigStore.savedURLString != nil else { return }
        guard RemoteConfigStore.shouldRefreshFromEndpoint else { return }
        RemoteConfigFetchService.shared.requestConfigRefresh()
    }
}

