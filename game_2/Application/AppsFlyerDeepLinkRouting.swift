import UIKit
import AppsFlyerLib

/// Проброс URL / Universal Links в AppsFlyer (OneLink / UDL). Associated Domains в entitlements должны совпадать с шаблоном OneLink.
enum AppsFlyerDeepLinkRouting {

    @discardableResult
    static func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }

    @discardableResult
    static func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }
}
