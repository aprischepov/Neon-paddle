import UIKit
enum PushNotificationRouting {
    private static var coldStartPushURL: URL?
    static func markColdStartPushURL(_ url: URL) {
        coldStartPushURL = url
    }
    static func openURLFromPushPayload(_ raw: String) {
        openURLFromPushPayload(raw, completion: nil)
    }
    static func openURLFromPushPayload(_ raw: String, completion: (() -> Void)?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = validatedContentURL(from: trimmed) else {
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
        if coldStartPushURL == url {
            coldStartPushURL = nil
            return
        }
        guard AppStartupSettings.resolvedMode != nil else {
            PendingPushURLStore.pendingURLString = originalString
            return
        }
        if openPushURLAsRoot(url) {
            PendingPushURLStore.pendingURLString = nil
        } else {
            PendingPushURLStore.pendingURLString = originalString
            DispatchQueue.main.async { flushPendingIfPossible() }
        }
    }
    static func flushPendingIfPossible() {
        guard let raw = PendingPushURLStore.pendingURLString,
              let url = validatedContentURL(from: raw) else {
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
        guard let window = keyWindow() else {
            return false
        }
        if let existing = window.rootViewController as? PushPayloadSurfaceController,
           existing.url == url {
            return true
        }
        let web = PushPayloadSurfaceController(url: url)
        UIView.transition(with: window, duration: 0.15, options: [.transitionCrossDissolve]) {
            window.rootViewController = web
        }
        window.makeKeyAndVisible()
        return true
    }
    private static func validatedContentURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }
}
