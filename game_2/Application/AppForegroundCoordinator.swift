import UIKit

enum AppForegroundCoordinator {
    static func applicationDidBecomeActive() {
        AnalyticsServices.applicationDidBecomeActive()
    }
}
