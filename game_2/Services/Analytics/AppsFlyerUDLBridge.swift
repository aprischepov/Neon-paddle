import Foundation
import AppsFlyerLib

/// Приём данных Unified Deep Linking и сохранение для последующего POST конфига.
final class AppsFlyerUDLBridge: NSObject, DeepLinkDelegate {
    static let shared = AppsFlyerUDLBridge()

    private override init() {
        super.init()
    }

    func attach() {
        AppsFlyerLib.shared().deepLinkDelegate = self
    }

    func didResolveDeepLink(_ result: DeepLinkResult) {
        DispatchQueue.main.async {
            self.handle(result)
        }
    }

    private func handle(_ result: DeepLinkResult) {
        guard result.status == .found, let deepLink = result.deepLink else { return }

        let fromClickEvent = Self.normalizedClickEvent(deepLink)
        var merged = fromClickEvent
        Self.supplement(from: deepLink, into: &merged)
        merged = AppsFlyerConversionPayload.sanitizedAttributionPayload(merged)

        guard AppsFlyerConversionPayload.isSubstantiveAttributionPayload(merged) else { return }

        AppsFlyerUDLPayloadStore.save(merged)
        NotificationCenter.default.post(name: .appsFlyerUDLPayloadDidUpdate, object: nil)
        RemoteConfigCoordinator.shared.notifyConfigContextUpdated()
    }

    private static func normalizedClickEvent(_ deepLink: DeepLink) -> [String: Any] {
        let event = deepLink.clickEvent
        var raw: [AnyHashable: Any] = [:]
        raw.reserveCapacity(event.count)
        for (key, value) in event {
            raw[AnyHashable(key)] = value
        }
        return AppsFlyerConversionPayload.normalized(from: raw)
    }

    /// Поля из объекта `DeepLink`, если в `clickEvent` ещё нет такого ключа.
    private static func supplement(from deepLink: DeepLink, into merged: inout [String: Any]) {
        func put(_ key: String, _ value: Any?) {
            guard merged[key] == nil else { return }
            guard let value else { return }
            if let string = value as? String {
                guard !string.isEmpty else { return }
                merged[key] = string
            } else {
                merged[key] = value
            }
        }

        put("deep_link_value", deepLink.deeplinkValue)
        put("match_type", deepLink.matchType)
        put("click_http_referrer", deepLink.clickHTTPReferrer)
        put("media_source", deepLink.mediaSource)
        put("campaign", deepLink.campaign)
        put("campaign_id", deepLink.campaignId)
        put("af_sub1", deepLink.afSub1)
        put("af_sub2", deepLink.afSub2)
        put("af_sub3", deepLink.afSub3)
        put("af_sub4", deepLink.afSub4)
        put("af_sub5", deepLink.afSub5)

        if merged["is_deferred"] == nil {
            merged["is_deferred"] = deepLink.isDeferred
        }

        let clickEvent = deepLink.clickEvent
        for key in Self.oneLinkSupplementKeys {
            put(key, clickEvent[key])
        }
    }

    /// Поля OneLink / UDL, которые часто приходят только в `clickEvent`.
    private static let oneLinkSupplementKeys = [
        "is_retargeting",
        "agency",
        "adset",
        "af_adset",
        "af_channel",
        "af_keywords",
        "af_ad",
        "af_ad_id",
        "af_adset_id",
        "af_c_id",
        "af_siteid",
        "af_prt",
        "pid",
        "c",
    ]
}
