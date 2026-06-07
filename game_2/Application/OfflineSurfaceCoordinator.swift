import UIKit
enum OfflineSurfaceCoordinator {
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
    static func syncWithConnectivityIfNeeded() {
        presentNoInternetIfNeeded()
    }
    private static func presentNoInternetIfNeeded() {
        guard AppStartupSettings.resolvedMode == .inlineSurface else { return }
        guard !ConnectivityMonitor.shared.isOnline else { return }
        guard let urlString = RemoteConfigStore.savedURLString, !urlString.isEmpty, URL(string: urlString) != nil else { return }
        guard let window = keyWindow() else { return }
        guard InlineFramePresenter.isActiveSurface(window.rootViewController) else { return }
        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
            window.rootViewController = NoInternetViewController(reason: .recurringSurfaceOffline)
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
