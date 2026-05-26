import Foundation
import AppsFlyerLib

final class AppsFlyerAttributionService: NSObject {
    static let shared = AppsFlyerAttributionService()

    private var isConfigured = false

    private override init() {
        super.init()
    }

    func configure() {
        let devKey = ThirdPartyKeys.appsFlyerDevKey
        let appId = ThirdPartyKeys.appsFlyerAppleAppID
        guard !devKey.isEmpty, !appId.isEmpty else {
            AppLogger.debug("AppsFlyer skipped: missing keys in ThirdPartyKeys", category: "AppsFlyer")
            return
        }

        let lib = AppsFlyerLib.shared()
        lib.appsFlyerDevKey = devKey
        lib.appleAppID = appId
        lib.delegate = self
        #if DEBUG
        lib.isDebug = true
        #endif
        isConfigured = true
    }

    func startSession() {
        guard isConfigured else { return }
        AppsFlyerLib.shared().start()
        AppLogger.debug("AppsFlyer session started", category: "AppsFlyer")
    }
}

extension AppsFlyerAttributionService: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {}

    func onConversionDataFail(_ error: Error) {
        AppLogger.warning("AppsFlyer conversion data failed", properties: [
            "error": error.localizedDescription
        ])
    }
}
