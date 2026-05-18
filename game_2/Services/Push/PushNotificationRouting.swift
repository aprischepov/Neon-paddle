import UIKit

/// Открытие `data.url` из push во **WKWebView**; URL не попадает в `RemoteConfigStore` и не дублируется в постоянное хранилище.
enum PushNotificationRouting {

    static func openURLFromPushPayload(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = validatedWebURL(from: trimmed) else { return }

        DispatchQueue.main.async {
            switch AppStartupSettings.resolvedMode {
            case .webView:
                if let web = resolveConfigWebViewController() {
                    web.loadPushOpenedURL(url)
                } else {
                    PendingPushURLStore.pendingURLString = trimmed
                }
            case .wrapper:
                if canPresentPushWebView() {
                    presentPushWebView(url: url)
                } else {
                    PendingPushURLStore.pendingURLString = trimmed
                }
            case nil:
                PendingPushURLStore.pendingURLString = trimmed
            }
        }
    }

    static func flushPendingIfPossible() {
        guard let raw = PendingPushURLStore.pendingURLString,
              let url = validatedWebURL(from: raw) else {
            PendingPushURLStore.pendingURLString = nil
            return
        }

        switch AppStartupSettings.resolvedMode {
        case .webView:
            guard let web = resolveConfigWebViewController() else { return }
            PendingPushURLStore.consumePending()
            web.loadPushOpenedURL(url)
        case .wrapper:
            guard canPresentPushWebView() else { return }
            PendingPushURLStore.consumePending()
            presentPushWebView(url: url)
        case nil:
            return
        }
    }

    private static func resolveConfigWebViewController() -> ConfigWebViewController? {
        guard let root = keyWindow()?.rootViewController else { return nil }
        if let web = root as? ConfigWebViewController { return web }
        if let web = topMost(from: root) as? ConfigWebViewController { return web }
        return nil
    }

    private static func keyWindow() -> UIWindow? {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let w = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            return w
        }
        return (UIApplication.shared.delegate as? AppDelegate)?.window
    }

    private static func presentPushWebView(url: URL) {
        guard let root = keyWindow()?.rootViewController else { return }
        let host = topMost(from: root)
        let pushWeb = PushPayloadWebViewController(url: url)
        host.present(pushWeb, animated: true)
    }

    private static func canPresentPushWebView() -> Bool {
        guard let root = keyWindow()?.rootViewController else { return false }
        guard root is GameViewController else { return false }
        return root.presentedViewController == nil
    }

    private static func validatedWebURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    private static func topMost(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topMost(from: presented)
        }
        if let nav = root as? UINavigationController, let visible = nav.visibleViewController {
            return topMost(from: visible)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(from: selected)
        }
        return root
    }
}
