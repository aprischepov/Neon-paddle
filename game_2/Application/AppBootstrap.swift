import UIKit

/// Старт приложения: аналитика, пуши, конфиг, сторонние SDK.
enum AppBootstrap {
    static func performLaunch(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        ConnectivityMonitor.shared.start()
        WebViewOfflineRootCoordinator.start()
        AppStartupDecisionCoordinator.shared.start()
        AnalyticsServices.configureAtLaunch(launchOptions: launchOptions)
    }
}
