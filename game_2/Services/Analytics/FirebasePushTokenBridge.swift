import Foundation
import UIKit
import FirebaseCore
import FirebaseMessaging
final class FirebasePushTokenBridge: NSObject, MessagingDelegate {
    static let shared = FirebasePushTokenBridge()
    private override init() {
        super.init()
    }
    func configure() {
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().isAutoInitEnabled = true
        Messaging.messaging().delegate = self
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
        Messaging.messaging().token { [weak self] token, _ in
            self?.applyFCMToken(token)
        }
    }
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        applyFCMToken(fcmToken)
    }
    private func applyFCMToken(_ token: String?) {
        guard let token, !token.isEmpty else { return }
        RemoteConfigRequestBuilder.setPushTokenForConfigRequests(token)
        RemoteConfigCoordinator.shared.notifyConfigContextUpdated()
    }
}
