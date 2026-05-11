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
            #if DEBUG
            print("[AppsFlyer] Пропуск: задайте appsFlyerDevKey и appsFlyerAppleAppID в ThirdPartyKeys.")
            #endif
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
    }
}

extension AppsFlyerAttributionService: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {}

    func onConversionDataFail(_ error: Error) {
        #if DEBUG
        print("[AppsFlyer] conversion data fail:", error.localizedDescription)
        #endif
    }
}
