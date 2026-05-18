import UserNotifications

/// Rich push: `aps.mutable-content = 1` + URL картинки в `userInfo` (как в рабочем шаблоне FCM).
final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        guard let imageURL = Self.imageURL(from: bestAttemptContent.userInfo) else {
            contentHandler(bestAttemptContent)
            return
        }

        Self.downloadAttachment(from: imageURL) { attachment in
            if let attachment {
                bestAttemptContent.attachments = [attachment]
            }
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        guard let contentHandler, let bestAttemptContent else { return }
        contentHandler(bestAttemptContent)
    }

    // MARK: - URL картинки (шаблон с рабочего проекта + `data` для FCM)

    private static func imageURL(from userInfo: [AnyHashable: Any]) -> URL? {
        let rootKeys = ["image", "image_url", "picture", "icon", "icon_url"]
        for key in rootKeys {
            if let url = url(from: userInfo[key]) { return url }
        }

        if let fcmOptions = userInfo["fcm_options"] as? [String: Any],
           let url = url(from: fcmOptions["image"]) {
            return url
        }

        if let data = userInfo["data"] as? [String: Any] {
            for key in rootKeys {
                if let url = url(from: data[key]) { return url }
            }
        }

        return nil
    }

    private static func url(from value: Any?) -> URL? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    // MARK: - Загрузка

    private static func downloadAttachment(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        URLSession.shared.downloadTask(with: url) { temporaryURL, _, _ in
            guard let temporaryURL else {
                completion(nil)
                return
            }

            let fileManager = FileManager.default
            let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString, isDirectory: true)

            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                let fileURL = directoryURL.appendingPathComponent(url.lastPathComponentWithFallback)
                try fileManager.moveItem(at: temporaryURL, to: fileURL)
                completion(try UNNotificationAttachment(identifier: "image", url: fileURL))
            } catch {
                completion(nil)
            }
        }.resume()
    }
}

private extension URL {
    var lastPathComponentWithFallback: String {
        let value = lastPathComponent
        guard !value.isEmpty else { return "image.jpg" }
        return value
    }
}
