import Foundation
import AppsFlyerLib
import FirebaseCore
import FirebaseMessaging

/// Тело `POST` для `AppConstants.RemoteConfig.endpointURL`.
///
/// **Conversion:** все ключи/значения из `conversionPayload` передаются как есть.
/// **UDL:** затем добавляются поля deep link, только если ключа ещё нет (первые полученные данные — из conversion).
/// **Клиент / FCM:** затем недостающие служебные поля.
enum RemoteConfigRequestBuilder {

    /// Собирает словарь для `JSONSerialization` / `URLRequest.httpBody`.
    static func postBodyDictionary(conversionPayload: [String: Any]?) -> [String: Any] {
        var body = AppsFlyerConversionPayload.sanitizedAttributionPayload(conversionPayload ?? [:])
        mergeUDLPayloadIfAbsent(into: &body)
        mergeClientFieldsIfAbsent(into: &body)
        return AppsFlyerConversionPayload.sanitizedAttributionPayload(body)
    }

    static func postBodyJSONData(conversionPayload: [String: Any]?) -> Data? {
        let dict = postBodyDictionary(conversionPayload: conversionPayload)
        guard JSONSerialization.isValidJSONObject(dict) else { return nil }
        /// Без сортировки ключей — порядок полей ближе к исходному словарю conversion.
        return try? JSONSerialization.data(withJSONObject: dict, options: [])
    }

    /// UDL после conversion: ключи из deep link добавляются только если в conversion **ещё нет** ключа (первые данные имеют приоритет).
    private static func mergeUDLPayloadIfAbsent(into body: inout [String: Any]) {
        guard let udl = AppsFlyerUDLPayloadStore.currentPayload() else { return }
        let sanitized = AppsFlyerConversionPayload.sanitizedAttributionPayload(udl)
        guard AppsFlyerConversionPayload.isSubstantiveAttributionPayload(sanitized) else { return }
        for (key, value) in sanitized {
            guard body[key] == nil else { continue }
            body[key] = value
        }
    }

    private static func mergeClientFieldsIfAbsent(into body: inout [String: Any]) {
        setIfAbsent("af_id", AppsFlyerLib.shared().getAppsFlyerUID(), in: &body)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.igordaurenev.glowbounce.app"
        setIfAbsent("bundle_id", bundleID, in: &body)
        setIfAbsent("os", "iOS", in: &body)
        setIfAbsent("store_id", iosStoreIdForConfig(), in: &body)
        setIfAbsent("locale", localeRFC3066Style(), in: &body)
        mergeFirebaseMessagingFieldsIfAvailable(into: &body)
    }

    /// iOS: `store_id` со строковым префиксом `id` + числовой App Store ID, например `id84435554334`.
    private static func iosStoreIdForConfig() -> String? {
        let raw = ThirdPartyKeys.appsFlyerAppleAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
        if lower.hasPrefix("id") { return raw }
        return "id\(raw)"
    }

    /// Локаль в духе RFC 3066: `en`, `ru`, `en_US` (идентификатор локали iOS с подчёркиванием региона).
    private static func localeRFC3066Style() -> String {
        Locale.current.identifier.replacingOccurrences(of: "-", with: "_")
    }

    /// Поля FCM только если инициализирован Firebase (`FirebaseApp`); иначе ключи не добавляются.
    private static func mergeFirebaseMessagingFieldsIfAvailable(into body: inout [String: Any]) {
        guard FirebaseApp.app() != nil else { return }

        if let token = pushTokenIfAvailable(), !token.isEmpty {
            setIfAbsent("push_token", token, in: &body)
        }

        if let projectId = firebaseProjectIdFromPlist(), !projectId.isEmpty {
            setIfAbsent("firebase_project_id", projectId, in: &body)
        }
    }

    private static func setIfAbsent(_ key: String, _ value: Any?, in body: inout [String: Any]) {
        guard body[key] == nil else { return }
        guard let value else { return }
        body[key] = value
    }

    private static let pushTokenUserDefaultsKey = "RemoteConfigPushDeviceToken"

    static func setPushTokenForConfigRequests(_ token: String?) {
        if let token, !token.isEmpty {
            UserDefaults.standard.set(token, forKey: pushTokenUserDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: pushTokenUserDefaultsKey)
        }
    }

    private static func pushTokenIfAvailable() -> String? {
        guard FirebaseApp.app() != nil else { return nil }
        if let token = Messaging.messaging().fcmToken, !token.isEmpty {
            return token
        }
        return UserDefaults.standard.string(forKey: pushTokenUserDefaultsKey)
    }

    /// `Project ID` или числовой идентификатор из plist (часто `GCM_SENDER_ID`).
    private static func firebaseProjectIdFromPlist() -> String? {
        guard FirebaseApp.app() != nil else { return nil }
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        if let projectId = plist["PROJECT_ID"] as? String, !projectId.isEmpty {
            return projectId
        }
        if let gcm = plist["GCM_SENDER_ID"] as? String, !gcm.isEmpty {
            return gcm
        }
        if let gcmNum = plist["GCM_SENDER_ID"] {
            return String(describing: gcmNum)
        }
        return nil
    }
}
