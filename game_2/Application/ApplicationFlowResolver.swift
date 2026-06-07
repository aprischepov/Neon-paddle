import UIKit
enum ApplicationFlowResolver {
    static func transitionFromSplash(window: UIWindow) {
        if let mode = AppStartupSettings.resolvedMode {
            switch mode {
            case .inlineSurface:
                transitionRecurringSurfaceLaunch(window: window)
            case .wrapper:
                installWrapperRoot(in: window)
            }
            return
        }
        if !ConnectivityMonitor.shared.isOnline {
            window.rootViewController = NoInternetViewController(reason: .firstLaunchConfigPending)
            return
        }
    }
    static func makeSplashRootFromStoryboard() -> UIViewController? {
        UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
    }
    private static func transitionRecurringSurfaceLaunch(window: UIWindow) {
        guard let urlString = RemoteConfigStore.savedURLString,
              URL(string: urlString) != nil else {
            installWrapperRoot(in: window)
            return
        }
        if !ConnectivityMonitor.shared.isOnline {
            window.rootViewController = NoInternetViewController(reason: .recurringSurfaceOffline)
            return
        }
        installSurfaceRoot(in: window, deferContentLoadUntilConfigRefresh: RemoteConfigStore.shouldRefreshFromEndpoint)
        if RemoteConfigStore.shouldRefreshFromEndpoint {
            RemoteConfigFetchService.shared.requestConfigRefresh()
        }
    }
    static func installSurfaceRoot(in window: UIWindow, deferContentLoadUntilConfigRefresh: Bool = false) {
        guard let urlString = RemoteConfigStore.savedURLString,
              let url = URL(string: urlString) else {
            installWrapperRoot(in: window)
            return
        }
        let web = InlineFramePresenter.makeSurface(
            url: url,
            deferRemoteSync: deferContentLoadUntilConfigRefresh
        )
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = web
        } completion: { _ in
            PushNotificationRouting.flushPendingIfPossible()
        }
    }
    static func installWrapperRoot(in window: UIWindow) {
        let menu = MainMenuFlowController.makeRootViewController()
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = menu
        } completion: { _ in
            PushNotificationRouting.flushPendingIfPossible()
        }
    }
    static func makeGameViewController() -> UIViewController? {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: "GameViewController")
    }
    static func applyRoutingReadyIfNeeded(window: UIWindow?) {
        guard let window else { return }
        guard let mode = AppStartupSettings.resolvedMode else { return }
        switch mode {
        case .inlineSurface:
            if !ConnectivityMonitor.shared.isOnline {
                window.rootViewController = NoInternetViewController(reason: .recurringSurfaceOffline)
                PushNotificationRouting.flushPendingIfPossible()
                return
            }
            installSurfaceRoot(in: window, deferContentLoadUntilConfigRefresh: RemoteConfigStore.shouldRefreshFromEndpoint)
            if RemoteConfigStore.shouldRefreshFromEndpoint {
                RemoteConfigFetchService.shared.requestConfigRefresh()
            }
        case .wrapper:
            installWrapperRoot(in: window)
        }
    }
}
