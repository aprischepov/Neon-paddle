import UIKit
import UserNotifications

/// Переключатель уведомлений в настройках игры: только сохранённое значение и системный диалог разрешения при включении.
enum GameNotificationPreferenceStore {
    private static let key = "game.settings.userRemoteNotificationsEnabled"
    private static let defaults = UserDefaults.standard

    static var isUserRemoteNotificationsEnabled: Bool {
        get {
            if defaults.object(forKey: key) == nil { return false }
            return defaults.bool(forKey: key)
        }
        set { defaults.set(newValue, forKey: key) }
    }

    static func notificationsPickerTitle(isEnabled: Bool) -> String {
        isEnabled ? "On" : "Off"
    }

    /// Включение: показываем стандартный системный запрос (если статус ещё не финальный — iOS сам решает, показывать диалог или нет).
    static func applyEnableFromSettings(onBlocked: @escaping () -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    isUserRemoteNotificationsEnabled = false
                    onBlocked()
                }
            }
        }
    }
}
