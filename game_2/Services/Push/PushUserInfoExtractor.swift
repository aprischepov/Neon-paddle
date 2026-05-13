import Foundation

/// Достаёт `url` из `data` payload FCM (как в `message.data.url`); ссылку из push **нельзя** писать в `RemoteConfigStore`.
enum PushUserInfoExtractor {

    /// Порядок: `data.url` (объект или JSON-строка), вложенный `message.data`, плоские ключи, `gcm.notification.*`.
    static func urlString(from userInfo: [AnyHashable: Any]) -> String? {
        if let s = urlFromDataField(userInfo["data"]) { return s }
        if let message = userInfo["message"] as? [String: Any],
           let s = urlFromDataField(message["data"]) {
            return s
        }
        if let s = string(from: userInfo["url"]) { return s }
        if let s = string(from: userInfo["link"]) { return s }
        for key in ["gcm.notification.link", "gcm.notification.url"] {
            if let s = string(from: userInfo[AnyHashable(key)]) { return s }
        }
        return nil
    }

    private static func urlFromDataField(_ value: Any?) -> String? {
        if let dict = value as? [String: Any] {
            if let s = string(from: dict["url"]) { return s }
            if let s = string(from: dict["link"]) { return s }
            return nil
        }
        if let str = value as? String,
           let data = str.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return string(from: obj["url"]) ?? string(from: obj["link"])
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
}
