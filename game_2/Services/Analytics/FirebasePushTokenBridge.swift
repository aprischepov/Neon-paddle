import Foundation
import UIKit
import FirebaseCore
import FirebaseMessaging

/// FCM registration token для `push_token` в конфиг-запросе: не вводится вручную, приходит из Firebase Messaging.
final class FirebasePushTokenBridge: NSObject, MessagingDelegate {
    static let shared = FirebasePushTokenBridge()

    private override init() {
        super.init()
    }

    func configure() {
        guard FirebaseApp.app() != nil else { return }

        Messaging.messaging().isAutoInitEnabled = true
        Messaging.messaging().delegate = self

        // Системный запрос разрешения показывается только после кастомного пре-промпта в WebView (`PushNotificationPrePromptCoordinator`).
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
