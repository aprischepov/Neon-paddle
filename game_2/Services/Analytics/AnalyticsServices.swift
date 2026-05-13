import UIKit

/// Единая точка старта аналитики и атрибуции.
enum AnalyticsServices {

    static func configureAtLaunch(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        _ = launchOptions
        FirebaseCrashlyticsService.configure()
        FirebasePushTokenBridge.shared.configure()
        AmplitudeAnalyticsService.shared.start()
        AppsFlyerAttributionService.shared.configure()
        RemoteConfigCoordinator.shared.start()
    }

    static func applicationDidBecomeActive() {
        AppTrackingService.requestAuthorizationThen {
            AppsFlyerAttributionService.shared.startSession()
        }
    }
}
