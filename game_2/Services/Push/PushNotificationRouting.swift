import UIKit

/// Открытие `data.url` из push во **WKWebView**; URL не попадает в `RemoteConfigStore` и не дублируется в постоянное хранилище.
enum PushNotificationRouting {

    static func openURLFromPushPayload(_ raw: String) {
        openURLFromPushPayload(raw, completion: nil)
    }

    static func openURLFromPushPayload(_ raw: String, completion: (() -> Void)?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = validatedWebURL(from: trimmed) else {
            completion?()
            return
        }

        let route = {
            routeValidatedPushURL(url, originalString: trimmed)
            completion?()
        }

        if Thread.isMainThread {
            route()
        } else {
            DispatchQueue.main.async(execute: route)
        }
    }

    private static func routeValidatedPushURL(_ url: URL, originalString: String) {
        // Если startup ещё не завершён — сохраняем, откроем после того как root установлен.
        // Иначе startup перетрёт push WebView (race condition cold start).
        guard AppStartupSettings.resolvedMode != nil else {
            PendingPushURLStore.pendingURLString = originalString
            return
        }
        if openPushURLAsRoot(url) {
            PendingPushURLStore.pendingURLString = nil
        } else {
            // Window ещё не готово (редкий момент между willEnterForeground и didBecomeActive).
            // Сохраняем и немедленно ретраим на следующем цикле run loop — к тому времени
            // окно гарантированно появится, а applicationDidBecomeActive уже мог отработать
            // раньше didReceive, поэтому нельзя полагаться только на его flush.
            PendingPushURLStore.pendingURLString = originalString
            DispatchQueue.main.async { flushPendingIfPossible() }
        }
    }

    static func flushPendingIfPossible() {
        guard let raw = PendingPushURLStore.pendingURLString,
              let url = validatedWebURL(from: raw) else {
            PendingPushURLStore.pendingURLString = nil
            return
        }

        if openPushURLAsRoot(url) {
            PendingPushURLStore.consumePending()
        }
    }

    private static func keyWindow() -> UIWindow? {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let w = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            return w
        }
        return (UIApplication.shared.delegate as? AppDelegate)?.window
    }

    @discardableResult
    private static func openPushURLAsRoot(_ url: URL) -> Bool {
        guard let window = keyWindow() else { return false }
        let web = PushPayloadWebViewController(url: url)
        window.rootViewController = web
        window.makeKeyAndVisible()
        return true
    }

    private static func validatedWebURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }
}
