import UIKit

/// Открытие `data.url` из push во **WKWebView**; URL не попадает в `RemoteConfigStore` и не дублируется в постоянное хранилище.
enum PushNotificationRouting {

    /// URL, полученный через `launchOptions` при cold start.
    /// iOS дополнительно вызывает `didReceive(response:)` для той же нотификации —
    /// этот флаг позволяет пропустить дублирующий вызов и не создавать второй WebVC.
    private static var coldStartPushURL: URL?

    /// Вызывается из `AppDelegate.didFinishLaunchingWithOptions`, когда push URL найден в `launchOptions`.
    static func markColdStartPushURL(_ url: URL) {
        print("[PUSH][routing] markColdStartPushURL: \(url)")
        coldStartPushURL = url
    }

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
        print("[PUSH][routing] routeValidatedPushURL url=\(url) resolvedMode=\(String(describing: AppStartupSettings.resolvedMode)) coldStart=\(String(describing: coldStartPushURL))")

        if coldStartPushURL == url {
            print("[PUSH][routing] cold-start dedup — skipping didReceive duplicate")
            coldStartPushURL = nil
            return
        }

        guard AppStartupSettings.resolvedMode != nil else {
            print("[PUSH][routing] resolvedMode=nil — saving to pending, will open after startup")
            PendingPushURLStore.pendingURLString = originalString
            return
        }
        if openPushURLAsRoot(url) {
            print("[PUSH][routing] openPushURLAsRoot SUCCESS")
            PendingPushURLStore.pendingURLString = nil
        } else {
            print("[PUSH][routing] openPushURLAsRoot FAILED (no keyWindow) — saving to pending + async retry")
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
        print("[PUSH][routing] flushPendingIfPossible url=\(url)")
        if openPushURLAsRoot(url) {
            print("[PUSH][routing] flush SUCCESS")
            PendingPushURLStore.consumePending()
        } else {
            print("[PUSH][routing] flush FAILED — keyWindow still nil")
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
        guard let window = keyWindow() else {
            print("[PUSH][routing] openPushURLAsRoot FAILED — keyWindow=nil")
            return false
        }
        let currentRootType = type(of: window.rootViewController as AnyObject)
        print("[PUSH][routing] openPushURLAsRoot url=\(url) currentRoot=\(currentRootType)")

        if let existing = window.rootViewController as? PushPayloadWebViewController,
           existing.url == url {
            print("[PUSH][routing] already showing PushPayloadWebVC with same url — skip duplicate")
            return true
        }

        let web = PushPayloadWebViewController(url: url)
        UIView.transition(with: window, duration: 0.15, options: [.transitionCrossDissolve]) {
            window.rootViewController = web
        }
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
