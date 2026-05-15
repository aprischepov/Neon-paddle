import Foundation

/// Нормализация словаря AppsFlyer (`[AnyHashable: Any]`) в JSON-совместимый `[String: Any]` без потери вложенности.
enum AppsFlyerConversionPayload {

    /// Служебные ключи SDK / HTTP, не отправляемые в `config.php`.
    private static let nonAttributionKeys: Set<String> = [
        "statusCode",
        "status",
        "error",
        "errorCode",
        "error_description",
        "type",
        "code",
        "httpStatus",
    ]

    static func sanitizedAttributionPayload(_ payload: [String: Any]) -> [String: Any] {
        payload.filter { !nonAttributionKeys.contains($0.key) }
    }

    /// Есть ли в словаре данные install / campaign attribution (не только client fields).
    static func isSubstantiveAttributionPayload(_ payload: [String: Any]) -> Bool {
        let keys = Set(payload.keys)
        if keys.contains("af_status") { return true }
        if keys.contains("media_source") { return true }
        if keys.contains("campaign") { return true }
        if keys.contains("install_time") { return true }
        if keys.contains("deep_link_value") { return true }
        if keys.contains("af_sub1") { return true }
        if keys.contains("is_retargeting") { return true }
        return false
    }

    /// Новые поля добавляются; существующие attribution-ключи не затираются пустым/служебным callback.
    static func mergingAttribution(existing: [String: Any], incoming: [String: Any]) -> [String: Any] {
        var merged = sanitizedAttributionPayload(existing)
        for (key, value) in sanitizedAttributionPayload(incoming) {
            if merged[key] == nil {
                merged[key] = value
                continue
            }
            if isSubstantiveAttributionPayload([key: value]) || !isSubstantiveAttributionPayload(merged) {
                merged[key] = value
            }
        }
        return merged
    }

    static func normalized(from raw: [AnyHashable: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        result.reserveCapacity(raw.count)
        for (key, value) in raw {
            let stringKey = stringKey(from: key)
            result[stringKey] = jsonSafeValue(value)
        }
        return result
    }

    static func jsonData(from dictionary: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
    }

    static func dictionary(from jsonData: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: jsonData)) as? [String: Any]
    }

    private static func stringKey(from key: AnyHashable) -> String {
        switch key {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return String(describing: key)
        }
    }

    private static func jsonSafeValue(_ value: Any) -> Any {
        switch value {
        case let dict as [AnyHashable: Any]:
            return normalized(from: dict)
        case let dict as [String: Any]:
            var out: [String: Any] = [:]
            out.reserveCapacity(dict.count)
            for (key, nested) in dict {
                out[key] = jsonSafeValue(nested)
            }
            return out
        case let array as [Any]:
            return array.map { jsonSafeValue($0) }
        case is NSNull:
            return NSNull()
        case let number as NSNumber:
            return number
        case let string as String:
            return string
        case let bool as Bool:
            return bool
        case let int as Int:
            return int
        case let double as Double:
            return double
        case let float as Float:
            return Double(float)
        default:
            return String(describing: value)
        }
    }
}

extension Notification.Name {
    /// `userInfo["payload"]` — `[String: Any]` полный нормализованный словарь conversion data.
    static let appsFlyerConversionDataDidUpdate = Notification.Name("appsFlyerConversionDataDidUpdate")

    /// `userInfo["errorDescription"]` — `String`.
    static let appsFlyerConversionDataDidFail = Notification.Name("appsFlyerConversionDataDidFail")
}
