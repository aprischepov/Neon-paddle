import Foundation

/// Фиксирует режим по ответу конфига: **WebView** (1.1) или **обёртка** (1.2); транспортные сбои (1.3) режим не трогают.
/// После первого сохранённого режима уведомления игнорируются (режим не перезаписывается).
final class AppStartupDecisionCoordinator {
    static let shared = AppStartupDecisionCoordinator()

    private var successObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?

    private init() {}

    func start() {
        guard successObserver == nil else { return }

        successObserver = NotificationCenter.default.addObserver(
            forName: .remoteConfigDidUpdate,
            object: nil,
            queue: .main
        ) { _ in
            guard AppStartupSettings.resolvedMode == nil else { return }
            AppStartupSettings.setResolved(.webView)
            NotificationCenter.default.post(name: .appStartupRoutingReady, object: nil)
        }

        failureObserver = NotificationCenter.default.addObserver(
            forName: .remoteConfigDidFail,
            object: nil,
            queue: .main
        ) { note in
            guard AppStartupSettings.resolvedMode == nil else { return }
            let hasHTTP = note.userInfo?[RemoteConfigFetchService.httpStatusUserInfoKey] != nil
            if hasHTTP {
                AppStartupSettings.setResolved(.wrapper)
                NotificationCenter.default.post(name: .appStartupRoutingReady, object: nil)
            } else {
                NotificationCenter.default.post(name: .appStartupConfigTransportFailed, object: nil)
            }
        }
    }
}
