import Foundation

/// Нормализация словаря AppsFlyer (`[AnyHashable: Any]`) в JSON-совместимый `[String: Any]` без потери вложенности.
enum AppsFlyerConversionPayload {

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
