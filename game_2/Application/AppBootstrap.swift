import UIKit

enum AppBootstrap {
    static func performLaunch(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        AnalyticsServices.configureAtLaunch(launchOptions: launchOptions)
    }
}
