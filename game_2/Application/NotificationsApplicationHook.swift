import UIKit
import FirebaseMessaging

/// Регистрация удалённых уведомлений: связка APNs device token ↔ Firebase Messaging.
enum NotificationsApplicationHook {
    static func didRegister(deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    static func registrationDidFail(error: Error) {
        #if DEBUG
        print("[APNs] registration failed:", error.localizedDescription)
        #endif
    }
}
