import UIKit
import UserNotifications
import FirebaseMessaging
final class PushNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationCenterDelegate()
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        _ = center
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
        Messaging.messaging().appDidReceiveMessage(userInfo)
        if let urlString = PushUserInfoExtractor.urlString(from: userInfo) {
            PushNotificationRouting.openURLFromPushPayload(urlString, completion: completionHandler)
        } else {
            completionHandler()
        }
    }
}
