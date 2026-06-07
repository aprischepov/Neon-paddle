import UIKit
import UserNotifications
enum PushNotificationPrePromptCoordinator {
    static func runIfNeededBeforeSurfaceContent(from host: UIViewController, completion: @escaping () -> Void) {
        guard AppStartupSettings.resolvedMode == .inlineSurface else {
            DispatchQueue.main.async(execute: completion)
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    PushPrePromptStorage.markFullyAccepted()
                    completion()
                    return
                case .denied:
                    completion()
                    return
                case .notDetermined:
                    break
                @unknown default:
                    completion()
                    return
                }
                guard PushPrePromptStorage.shouldPresentCustomPrePrompt() else {
                    completion()
                    return
                }
                let prePrompt = PushNotificationPrePromptViewController(
                    onAllow: {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                            DispatchQueue.main.async {
                                if granted {
                                    PushPrePromptStorage.markFullyAccepted()
                                } else {
                                    PushPrePromptStorage.markPermanentDeclineAfterSystemDeny()
                                }
                                UIApplication.shared.registerForRemoteNotifications()
                                completion()
                            }
                        }
                    },
                    onSkip: {
                        PushPrePromptStorage.blockForThreeDays()
                        completion()
                    }
                )
                host.present(prePrompt, animated: true)
            }
        }
    }
}
