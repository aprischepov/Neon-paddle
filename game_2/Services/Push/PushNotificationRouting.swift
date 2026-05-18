import UIKit

/// Открытие `data.url` из push во **WKWebView**; URL не попадает в `RemoteConfigStore` и не дублируется в постоянное хранилище.
enum PushNotificationRouting {

    static func openURLFromPushPayload(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return }

        DispatchQueue.main.async {
            switch AppStartupSettings.resolvedMode {
            case .webView:
                if let web = resolveConfigWebViewController() {
                    web.loadPushOpenedURL(url)
                } else {
                    PendingPushURLStore.pendingURLString = trimmed
                }
            case .wrapper:
                presentPushWebView(url: url)
            case nil:
                PendingPushURLStore.pendingURLString = trimmed
            }
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
