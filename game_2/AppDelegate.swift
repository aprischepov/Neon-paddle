//
//  AppDelegate.swift
//  Glow Bounce
//
//  Created by Artem Prischepov on 1.05.26.
//

import UIKit
import UserNotifications
import FirebaseMessaging

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = PushNotificationCenterDelegate.shared

        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
           let urlString = PushUserInfoExtractor.urlString(from: remote) {
            PendingPushURLStore.pendingURLString = urlString
        }

        AppBootstrap.performLaunch(launchOptions: launchOptions)
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AppForegroundCoordinator.applicationDidBecomeActive()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationsApplicationHook.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationsApplicationHook.registrationDidFail(error: error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Messaging.messaging().appDidReceiveMessage(userInfo)
        completionHandler(.newData)
    }
}
