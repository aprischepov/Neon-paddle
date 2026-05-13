import UIKit

/// Логика при уходе приложения на передний план.
enum AppForegroundCoordinator {
    static func applicationDidBecomeActive() {
        AnalyticsServices.applicationDidBecomeActive()
        refreshRemoteConfigIfWebViewModeAndNeeded()
        flushPendingPushForWrapperMode()
    }

    /// Ссылка из cold start по push в режиме обёртки (WebView забирает pending в `ConfigWebViewController`).
    private static func flushPendingPushForWrapperMode() {
        guard AppStartupSettings.resolvedMode == .wrapper else { return }
        guard let raw = PendingPushURLStore.consumePending(), !raw.isEmpty else { return }
        PushNotificationRouting.openURLFromPushPayload(raw)
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

