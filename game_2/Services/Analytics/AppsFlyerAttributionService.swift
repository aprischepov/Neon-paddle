import Foundation
import AppsFlyerLib

/// Конфигурация AppsFlyer, старт сессии и **полный conversion payload** (GCD): память + `UserDefaults` + нотификации.
/// При первом запуске с `af_status = Organic` планируется одно повторное обращение к SDK через `deferredInstallConversionRefreshDelay`.
final class AppsFlyerAttributionService: NSObject {
    static let shared = AppsFlyerAttributionService()

    /// Ключ `userInfo` для `[String: Any]` payload в `.appsFlyerConversionDataDidUpdate`.
    static let conversionPayloadUserInfoKey = "payload"

    private var isConfigured = false

    private var deferredInstallConversionRefreshWorkItem: DispatchWorkItem?

    /// Последний успешный ответ `onConversionDataSuccess` (нормализованный словарь). Обновляется на главном потоке.
    private(set) var latestConversionPayload: [String: Any]?

    private override init() {
        super.init()
        latestConversionPayload = AppsFlyerConversionStore.load()
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
        AppsFlyerUDLBridge.shared.attach()
        #if DEBUG
        lib.isDebug = true
        #endif
        isConfigured = true
    }

    func startSession() {
        guard isConfigured else { return }
        AppsFlyerLib.shared().start()
    }

    /// Актуальный payload: из памяти или последний сохранённый между запусками.
    func currentConversionPayload() -> [String: Any]? {
        latestConversionPayload ?? AppsFlyerConversionStore.load()
    }

    /// JSON сериализация `currentConversionPayload()` — удобно для логов или сетевого тела.
    func currentConversionJSONData() -> Data? {
        guard let payload = currentConversionPayload() else { return nil }
        return AppsFlyerConversionPayload.jsonData(from: payload)
    }

    private func applyConversionSuccess(_ raw: [AnyHashable: Any]) {
        let normalized = AppsFlyerConversionPayload.normalized(from: raw)
        latestConversionPayload = normalized
        AppsFlyerConversionStore.save(normalized)
        scheduleDeferredInstallConversionRefreshIfNeeded(raw: raw)
        NotificationCenter.default.post(
            name: .appsFlyerConversionDataDidUpdate,
            object: self,
            userInfo: [Self.conversionPayloadUserInfoKey: normalized]
        )
    }

    private func scheduleDeferredInstallConversionRefreshIfNeeded(raw: [AnyHashable: Any]) {
        guard AppsFlyerInstallAttribution.shouldScheduleDeferredInstallConversionRefresh(afterReceiving: raw) else {
            return
        }
        deferredInstallConversionRefreshWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performDeferredInstallConversionRefresh()
        }
        deferredInstallConversionRefreshWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppsFlyerInstallAttribution.deferredInstallConversionRefreshDelay,
            execute: work
        )
    }

    /// Повторный старт SDK после паузы: даёт шанс обновить install attribution, если данные пришли с задержкой.
    private func performDeferredInstallConversionRefresh() {
        deferredInstallConversionRefreshWorkItem = nil
        AppsFlyerInstallAttribution.isDeferredInstallConversionRefreshCompleted = true

        guard isConfigured else { return }

        AppsFlyerLib.shared().start { [weak self] dictionary, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if let dictionary, !dictionary.isEmpty {
                    let bridged: [AnyHashable: Any] = Dictionary(uniqueKeysWithValues: dictionary.map { key, value in
                        (AnyHashable(key as String), value)
                    })
                    self.applyConversionSuccess(bridged)
                }
            }
        }
    }

    private func applyConversionFailure(_ error: Error) {
        #if DEBUG
        print("[AppsFlyer] conversion data fail:", error.localizedDescription)
        #endif
        NotificationCenter.default.post(
            name: .appsFlyerConversionDataDidFail,
            object: self,
            userInfo: ["errorDescription": error.localizedDescription]
        )
    }
}

extension AppsFlyerAttributionService: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        let snapshot = conversionInfo
        if Thread.isMainThread {
            applyConversionSuccess(snapshot)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applyConversionSuccess(snapshot)
            }
        }
    }

    func onConversionDataFail(_ error: Error) {
        if Thread.isMainThread {
            applyConversionFailure(error)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applyConversionFailure(error)
            }
        }
    }
}
