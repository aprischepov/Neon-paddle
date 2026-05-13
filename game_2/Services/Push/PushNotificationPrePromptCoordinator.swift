import UIKit
import UserNotifications

/// Кастомный пре-промпт только в режиме WebView, до загрузки контента WebView. Системный диалог — только после согласия на кастомном экране.
///
/// Сценарии: (1) первое согласие → системный запрос → разрешено; (2) «Не сейчас» → кастомный экран снова через 3 дня при `notDetermined`;
/// (3) согласие на кастомном, отказ в системном → флаг постоянного отказа, кастомный экран больше не показывается (системный запрос из приложения iOS не повторяет).
enum PushNotificationPrePromptCoordinator {

    static func runIfNeededBeforeWebContent(from host: UIViewController, completion: @escaping () -> Void) {
        guard AppStartupSettings.resolvedMode == .webView else {
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
                    // Повторно показать системный запрос из приложения нельзя; кастомный экран в этом состоянии не показываем.
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
