import UIKit

enum AppBootstrap {
    static func performLaunch(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        ConnectivityMonitor.shared.start()
        AnalyticsServices.configureAtLaunch(launchOptions: launchOptions)
        syncAnalyticsUserId()
        AppLogger.track(AppLogger.Event.appLaunched)
        AppLogger.debug("App launched")
    }

    private static func syncAnalyticsUserId() {
        guard let name = PlayerProfileStore.displayName, !name.isEmpty else { return }
        AmplitudeAnalyticsService.shared.setUserId(name)
    }
}
