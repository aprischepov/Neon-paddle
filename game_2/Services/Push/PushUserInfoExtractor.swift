import Foundation

/// Достаёт `url` из `data` payload FCM (`message.data.url`); ссылку из push **нельзя** писать в `RemoteConfigStore`.
enum PushUserInfoExtractor {

    /// Приоритет: `data.url` / `message.data.url` (контракт), затем плоские ключи из FCM data, без `gcm.notification.link`.
    static func urlString(from userInfo: [AnyHashable: Any]) -> String? {
        if let s = urlFromDataField(userInfo["data"]) { return s }
        if let message = dictionary(from: userInfo["message"]) {
            if let s = urlFromDataField(message["data"]) {
                return s
            }
        }
        for key in ["url", "link", "click_url", "open_url", "target_url"] {
            if let s = httpURLString(from: userInfo[AnyHashable(key)]) { return s }
        }
        return nil
    }

    /// URL картинки (тот же разбор, что в Notification Service Extension).
    static func imageURLString(from userInfo: [AnyHashable: Any]) -> String? {
        PushPayloadParser.imageURLString(from: userInfo)
    }

    private static func urlFromDataField(_ value: Any?) -> String? {
        if let dict = dictionary(from: value) {
            for key in ["url", "link", "click_url", "open_url", "target_url"] {
                if let s = httpURLString(from: dict[key]) { return s }
            }
            return nil
        }
        if let str = value as? String,
           let data = str.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["url", "link", "click_url", "open_url", "target_url"] {
                if let s = httpURLString(from: obj[key]) { return s }
            }
        }
        return nil
    }

    private static func dictionary(from value: Any?) -> [String: Any]? {
        if let dict = value as? [String: Any] {
            return dict
        }
        if let dict = value as? [AnyHashable: Any] {
            var result: [String: Any] = [:]
            for (key, value) in dict {
                guard let key = key as? String else { continue }
                result[key] = value
            }
            return result
        }
        return nil
    }

    private static func string(from value: Any?) -> String? {
        guard let raw = value else { return nil }
        let s: String?
        if let str = raw as? String { s = str }
        else if let num = raw as? NSNumber { s = num.stringValue }
        else { return nil }
        let trimmed = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func httpURLString(from value: Any?) -> String? {
        guard let s = string(from: value) else { return nil }
        guard let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return s
    }
}
