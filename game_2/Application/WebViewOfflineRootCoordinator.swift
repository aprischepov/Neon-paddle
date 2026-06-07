import UIKit

/// П. «нет сети» при **потере** соединения, пока открыт WebView: холодный старт уже обрабатывается в `ApplicationFlowResolver`.
///
/// **Симулятор:** сеть идёт через хост; при выключении только Wi‑Fi на Mac путь часто остаётся `satisfied` (Ethernet / другой интерфейс). Имеет смысл тестировать **Network Link Conditioner** (100% loss) или **устройство**. Дополнительно дергаем проверку в `applicationDidBecomeActive`, т.к. `NWPathMonitor` иногда обновляется с задержкой.
enum WebViewOfflineRootCoordinator {
    private static var observer: NSObjectProtocol?

    static func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .connectivityDidChange,
            object: nil,
            queue: .main
        ) { _ in
            presentNoInternetIfNeeded()
        }
    }

    /// Повторная синхронизация при возврате на передний план (симулятор / пропущенный нотификационный цикл).
    static func syncWithConnectivityIfNeeded() {
        presentNoInternetIfNeeded()
    }

    private static func presentNoInternetIfNeeded() {
        guard AppStartupSettings.resolvedMode == .webView else { return }
        guard !ConnectivityMonitor.shared.isOnline else { return }
        guard let urlString = RemoteConfigStore.savedURLString, !urlString.isEmpty, URL(string: urlString) != nil else { return }
        guard let window = keyWindow() else { return }
        guard window.rootViewController is ConfigWebViewController else { return }

        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
            window.rootViewController = NoInternetViewController(reason: .recurringWebViewOffline)
        }
    }

    private static func keyWindow() -> UIWindow? {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let w = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first {
            return w
        }
        return (UIApplication.shared.delegate as? AppDelegate)?.window
    }
}
