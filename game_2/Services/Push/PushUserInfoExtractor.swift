import Foundation

/// Достаёт `url` из push payload. Логика взята из референсного проекта (RandomWay), где работает.
/// Приоритет: `userInfo["url"]` → `userInfo["data"]["url"]` → `userInfo["data.url"]`.
enum PushUserInfoExtractor {

    static func urlString(from userInfo: [AnyHashable: Any]) -> String? {
        // 1. Плоский "url" в корне — самый частый случай в FCM
        if let s = validURL(userInfo["url"]) { return s }

        // 2. Вложенный "data.url" — контракт нашего бэкенда
        if let data = userInfo["data"] as? [String: Any],
           let s = validURL(data["url"]) { return s }

        // 3. FCM иногда кладёт data-поля в корень при killed-state
        if let s = validURL(userInfo["data.url"]) { return s }

        return nil
    }

    /// URL картинки (тот же разбор, что в Notification Service Extension).
    static func imageURLString(from userInfo: [AnyHashable: Any]) -> String? {
        PushPayloadParser.imageURLString(from: userInfo)
    }

    private static func validURL(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty,
              let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return s
    }
}
