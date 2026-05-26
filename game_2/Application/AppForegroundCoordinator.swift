import UIKit

enum AppForegroundCoordinator {
    static func applicationDidBecomeActive() {
        AppLogger.track(AppLogger.Event.appForeground)
        AnalyticsServices.applicationDidBecomeActive()
    }
}
