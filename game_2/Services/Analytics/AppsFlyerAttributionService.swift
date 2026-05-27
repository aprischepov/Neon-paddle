import Foundation
import AppsFlyerLib

final class AppsFlyerAttributionService: NSObject {
    static let shared = AppsFlyerAttributionService()

    static let conversionPayloadUserInfoKey = "payload"

    private var isConfigured = false
    private var deferredInstallConversionRefreshWorkItem: DispatchWorkItem?

    private(set) var latestConversionPayload: [String: Any]?

    private override init() {
        super.init()
        latestConversionPayload = AppsFlyerConversionStore.load()
    }

    // MARK: - Setup

    func configure() {
        let devKey = ThirdPartyKeys.appsFlyerDevKey
        let appId  = ThirdPartyKeys.appsFlyerAppleAppID
        guard !devKey.isEmpty, !appId.isEmpty else {
            AppLogger.debug("AppsFlyer skipped: missing keys in ThirdPartyKeys", category: "AppsFlyer")
            return
        }

        let lib = AppsFlyerLib.shared()
        lib.appsFlyerDevKey = devKey
        lib.appleAppID     = appId
        lib.delegate       = self
        #if DEBUG
        lib.isDebug = true
        #endif
        isConfigured = true
        AppLogger.debug("AppsFlyer configured", category: "AppsFlyer")
    }

    func startSession() {
        guard isConfigured else { return }
        AppsFlyerLib.shared().start()
        AppLogger.debug("AppsFlyer session started", category: "AppsFlyer")
    }

    // MARK: - Payload access

    func currentConversionPayload() -> [String: Any]? {
        latestConversionPayload ?? AppsFlyerConversionStore.load()
    }

    func currentConversionJSONData() -> Data? {
        guard let payload = currentConversionPayload() else { return nil }
        return AppsFlyerConversionPayload.jsonData(from: payload)
    }

    // MARK: - Private

    private var isVariantB: Bool {
        ABTestingService.shared.string(for: .appVariant)?.uppercased() == "B"
    }

    private func applyConversionSuccess(_ raw: [AnyHashable: Any]) {
        let variant = ABTestingService.shared.string(for: .appVariant) ?? "nil"
        guard isVariantB else {
            AppLogger.debug(
                "[AppsFlyer] onConversionDataSuccess received — SKIPPED ⛔️ (SplashScreenTest=\(variant))",
                category: "AppsFlyer"
            )
            return
        }
        AppLogger.debug(
            "[AppsFlyer] onConversionDataSuccess received — PROCESSING ✅ (SplashScreenTest=\(variant))",
            category: "AppsFlyer"
        )

        let normalized = AppsFlyerConversionPayload.normalized(from: raw)
        let incoming   = AppsFlyerConversionPayload.sanitizedAttributionPayload(normalized)

        guard AppsFlyerConversionPayload.isSubstantiveAttributionPayload(incoming) else {
            AppLogger.debug("AppsFlyer: non-attribution callback, ignoring", category: "AppsFlyer")
            return
        }

        let merged: [String: Any]
        if let existing = latestConversionPayload ?? AppsFlyerConversionStore.load() {
            merged = AppsFlyerConversionPayload.mergingAttribution(existing: existing, incoming: incoming)
        } else {
            merged = incoming
        }

        latestConversionPayload = merged
        AppsFlyerConversionStore.save(merged)

        AppLogger.track("appsflyer_conversion_received", properties: [
            "af_status": normalized["af_status"] as? String ?? "unknown",
            "media_source": normalized["media_source"] as? String ?? "none"
        ])

        scheduleDeferredRefreshIfNeeded(raw: raw)

        NotificationCenter.default.post(
            name: .appsFlyerConversionDataDidUpdate,
            object: self,
            userInfo: [Self.conversionPayloadUserInfoKey: merged]
        )
    }

    private func applyConversionFailure(_ error: Error) {
        AppLogger.warning("AppsFlyer conversion data failed", properties: [
            "error": error.localizedDescription
        ])
        NotificationCenter.default.post(
            name: .appsFlyerConversionDataDidFail,
            object: self,
            userInfo: ["errorDescription": error.localizedDescription]
        )
    }

    private func scheduleDeferredRefreshIfNeeded(raw: [AnyHashable: Any]) {
        guard AppsFlyerInstallAttribution.shouldScheduleDeferredInstallConversionRefresh(afterReceiving: raw) else {
            return
        }
        deferredInstallConversionRefreshWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performDeferredRefresh()
        }
        deferredInstallConversionRefreshWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppsFlyerInstallAttribution.deferredInstallConversionRefreshDelay,
            execute: work
        )
        AppLogger.debug("AppsFlyer: deferred refresh scheduled (Organic first launch)", category: "AppsFlyer")
    }

    private func performDeferredRefresh() {
        deferredInstallConversionRefreshWorkItem = nil
        AppsFlyerInstallAttribution.isDeferredInstallConversionRefreshCompleted = true

        guard isConfigured else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .appsFlyerDeferredInstallConversionRefreshDidFinish,
                    object: self
                )
            }
            return
        }

        AppLogger.debug("AppsFlyer: performing deferred conversion refresh", category: "AppsFlyer")
        AppsFlyerLib.shared().start { [weak self] dictionary, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if let dictionary, !dictionary.isEmpty {
                    let bridged: [AnyHashable: Any] = Dictionary(
                        uniqueKeysWithValues: dictionary.map { (AnyHashable($0.key as String), $0.value) }
                    )
                    self.applyConversionSuccess(bridged)
                }
                NotificationCenter.default.post(
                    name: .appsFlyerDeferredInstallConversionRefreshDidFinish,
                    object: self
                )
            }
        }
    }
}

// MARK: - AppsFlyerLibDelegate

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
