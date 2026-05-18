import UIKit

/// Корневой UI после сплеша: WebView, игра (обёртка) или первый запуск (сеть / ожидание конфига).
enum ApplicationFlowResolver {

    static func transitionFromSplash(window: UIWindow) {
        if let mode = AppStartupSettings.resolvedMode {
            switch mode {
            case .webView:
                transitionRecurringWebViewLaunch(window: window)
            case .wrapper:
                installWrapperRoot(in: window)
            }
            return
        }

        if !ConnectivityMonitor.shared.isOnline {
            window.rootViewController = NoInternetViewController(reason: .firstLaunchConfigPending)
            return
        }

        // Первый запуск + сеть: корень уже `SplashViewController` — конфиг и ожидание режима выполняются на сплеше.
    }

    /// Возврат с экрана «Нет сети» на первом запуске — снова сплеш с лоадинг-артом.
    static func makeSplashRootFromStoryboard() -> UIViewController? {
        UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
    }

    /// П. 2.1: WebView при каждом запуске; без сети — заглушка; с сетью — последняя ссылка + запрос эндпоинта при необходимости.
    private static func transitionRecurringWebViewLaunch(window: UIWindow) {
        guard let urlString = RemoteConfigStore.savedURLString,
              URL(string: urlString) != nil else {
            installWrapperRoot(in: window)
            return
        }
        if !ConnectivityMonitor.shared.isOnline {
            window.rootViewController = NoInternetViewController(reason: .recurringWebViewOffline)
            return
        }
        installWebViewRoot(in: window, deferContentLoadUntilConfigRefresh: RemoteConfigStore.shouldRefreshFromEndpoint)
        if RemoteConfigStore.shouldRefreshFromEndpoint {
            RemoteConfigFetchService.shared.requestConfigRefresh()
        }
    }

    static func installWebViewRoot(in window: UIWindow, deferContentLoadUntilConfigRefresh: Bool = false) {
        guard let urlString = RemoteConfigStore.savedURLString,
              let url = URL(string: urlString) else {
            installWrapperRoot(in: window)
            return
        }
        let web = ConfigWebViewController(
            url: url,
            deferContentLoadUntilConfigRefresh: deferContentLoadUntilConfigRefresh
        )
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = web
        }
    }

    static func installWrapperRoot(in window: UIWindow) {
        guard let game = makeGameViewController() else { return }
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = game
        }
    }

    static func makeGameViewController() -> UIViewController? {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: "GameViewController")
    }

    /// После `appStartupRoutingReady`: перейти к сохранённому режиму.
    static func applyRoutingReadyIfNeeded(window: UIWindow?) {
        guard let window else { return }
        guard let mode = AppStartupSettings.resolvedMode else { return }
        switch mode {
        case .webView:
            if !ConnectivityMonitor.shared.isOnline {
                window.rootViewController = NoInternetViewController(reason: .recurringWebViewOffline)
                return
            }
            installWebViewRoot(in: window, deferContentLoadUntilConfigRefresh: RemoteConfigStore.shouldRefreshFromEndpoint)
            if RemoteConfigStore.shouldRefreshFromEndpoint {
                RemoteConfigFetchService.shared.requestConfigRefresh()
            }
        case .wrapper:
            installWrapperRoot(in: window)
        }
    }
}
