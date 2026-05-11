import UIKit

/// Единая точка старта аналитики и атрибуции.
enum AnalyticsServices {

    static func configureAtLaunch(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        _ = launchOptions
        FirebaseCrashlyticsService.configure()
        AmplitudeAnalyticsService.shared.start()
        AppsFlyerAttributionService.shared.configure()
    }

    static func applicationDidBecomeActive() {
        AppsFlyerAttributionService.shared.startSession()
    }
}
