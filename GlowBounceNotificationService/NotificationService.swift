import UserNotifications
import UniformTypeIdentifiers

/*
 Сервер (FCM / APNs) для превью и большой картинки:
 - В `aps` обязательно **`mutable-content": 1`** (иначе расширение не вызывается).
 - URL картинки — в `data` рядом с остальными полями, например `"image": "https://..."` или `gcm.notification.image` (FCM).
 См. также: https://firebase.google.com/docs/cloud-messaging/ios/send-image
 */
/// Сервисное расширение для rich push с картинкой (`mutable-content: 1`). Ищет URL изображения в `userInfo` / `data`, скачивает и добавляет `UNNotificationAttachment`.
final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        guard let mutable = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        bestAttemptContent = mutable

        guard let urlString = Self.extractImageURLString(from: mutable.userInfo),
              let imageURL = URL(string: urlString) else {
            contentHandler(mutable)
            return
        }

        Self.downloadAttachment(from: imageURL) { [weak self] attachment in
            guard let self, let best = self.bestAttemptContent else {
                contentHandler(mutable)
                return
            }
            if let attachment {
                best.attachments = [attachment]
            }
            contentHandler(best)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    // MARK: - URL в payload (FCM / кастом)

    private static func extractImageURLString(from userInfo: [AnyHashable: Any]) -> String? {
        let flatKeys = [
            "image", "image_url", "imageUrl",
            "media-url", "media_url", "mediaUrl",
            "big_picture", "big-picture", "picture",
        ]
        for key in flatKeys {
            if let s = string(from: userInfo[AnyHashable(key)]) { return s }
        }
        if let s = string(from: userInfo[AnyHashable("gcm.notification.image")]) { return s }

        if let data = userInfo["data"] as? [String: Any] {
            for key in flatKeys {
                if let s = string(from: data[key]) { return s }
            }
        }
        if let dataStr = userInfo["data"] as? String,
           let d = dataStr.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            for key in flatKeys {
                if let s = string(from: obj[key]) { return s }
            }
        }
        if let message = userInfo["message"] as? [String: Any],
           let data = message["data"] as? [String: Any] {
            for key in flatKeys {
                if let s = string(from: data[key]) { return s }
            }
        }
        return nil
    }

    private static func string(from value: Any?) -> String? {
        guard let raw = value else { return nil }
        let s: String
        if let str = raw as? String { s = str }
        else if let num = raw as? NSNumber { s = num.stringValue }
        else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.hasPrefix("http") else { return nil }
        return trimmed
    }

    // MARK: - Загрузка

    private static func downloadAttachment(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, _ in
            guard let localURL else {
                completion(nil)
                return
            }
            let suggestedExt = response?.suggestedFilename.flatMap { URL(fileURLWithPath: $0).pathExtension }
            let ext = (suggestedExt?.isEmpty == false) ? suggestedExt! : url.pathExtension
            let normalizedExt = ext.lowercased().isEmpty ? "jpg" : ext.lowercased()

            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(normalizedExt)

            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.moveItem(at: localURL, to: dest)
                let typeHint = contentTypeHint(forExtension: normalizedExt)
                let attachment = try UNNotificationAttachment(
                    identifier: "push-image",
                    url: dest,
                    options: [UNNotificationAttachmentOptionsTypeHintKey: typeHint]
                )
                completion(attachment)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }

    private static func contentTypeHint(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "png": return UTType.png.identifier
        case "gif": return UTType.gif.identifier
        case "webp": return "public.webp"
        case "jpg", "jpeg": return UTType.jpeg.identifier
        default: return UTType.jpeg.identifier
        }
    }
}
