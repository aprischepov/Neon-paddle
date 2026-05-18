import Foundation

/// Разбор FCM payload (app); для image в NSE — тот же набор ключей, что в `NotificationService`.
enum PushPayloadParser {

    private static let imageKeys = ["image", "image_url", "picture", "icon", "icon_url"]

    static func imageURLString(from userInfo: [AnyHashable: Any]) -> String? {
        for key in imageKeys {
            if let s = string(from: userInfo[AnyHashable(key)]) { return s }
        }

        if let fcmOptions = userInfo["fcm_options"] as? [String: Any],
           let s = string(from: fcmOptions["image"]) {
            return s
        }

        if let data = userInfo["data"] as? [String: Any] {
            for key in imageKeys {
                if let s = string(from: data[key]) { return s }
            }
        }

        return nil
    }

    private static func string(from value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
