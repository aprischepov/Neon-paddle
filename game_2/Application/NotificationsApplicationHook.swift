import UIKit
import FirebaseMessaging
enum NotificationsApplicationHook {
    static func didRegister(deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    static func registrationDidFail(error: Error) {
    }
}
