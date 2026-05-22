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

        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            print("[PUSH][launchOptions] cold start from push, payload: \(remote)")
            if let urlString = PushUserInfoExtractor.urlString(from: remote) {
                print("[PUSH][launchOptions] extracted url=\(urlString)")
                PendingPushURLStore.pendingURLString = urlString
                // Помечаем URL как cold-start: iOS дополнительно вызовет didReceive(response:)
                // для той же нотификации, и PushNotificationRouting пропустит дублирующий вызов.
                if let url = URL(string: urlString) {
                    PushNotificationRouting.markColdStartPushURL(url)
                }
            } else {
                print("[PUSH][launchOptions] ⚠️ URL NOT FOUND in payload keys: \(remote.keys.map { "\($0)" })")
            }
        } else {
            print("[PUSH][launchOptions] no push in launchOptions (background launch or normal launch)")
        }

        if let url = launchOptions?[.url] as? URL {
            AppsFlyerDeepLinkRouting.application(application, open: url)
        }

        AppBootstrap.performLaunch(launchOptions: launchOptions)
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AppsFlyerDeepLinkRouting.application(app, open: url, options: options)
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        AppsFlyerDeepLinkRouting.application(
            application,
            continue: userActivity,
            restorationHandler: restorationHandler
        )
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
