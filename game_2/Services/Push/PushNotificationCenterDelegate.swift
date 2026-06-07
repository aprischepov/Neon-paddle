import UIKit
import UserNotifications
import FirebaseMessaging

/// Показ баннеров в форграунде и обработка тапа по push.
/// Картинка в развёрнутом уведомлении: таргет `GlowBounceNotificationService` + в payload APNs **`mutable-content`: 1** и URL изображения (ключи см. в `NotificationService.swift`).
final class PushNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationCenterDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        _ = center
        print("[PUSH][willPresent] foreground push received, userInfo: \(notification.request.content.userInfo)")
        Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        _ = center
        let userInfo = response.notification.request.content.userInfo
        print("[PUSH][didReceive] tap, isMainThread=\(Thread.isMainThread), userInfo: \(userInfo)")
        Messaging.messaging().appDidReceiveMessage(userInfo)
        if let urlString = PushUserInfoExtractor.urlString(from: userInfo) {
            print("[PUSH][didReceive] extracted url=\(urlString)")
            PushNotificationRouting.openURLFromPushPayload(urlString, completion: completionHandler)
        } else {
            print("[PUSH][didReceive] ⚠️ URL NOT FOUND in payload keys: \(userInfo.keys.map { "\($0)" })")
            completionHandler()
        }
    }
}
