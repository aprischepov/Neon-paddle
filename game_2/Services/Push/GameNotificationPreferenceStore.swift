import UIKit
import UserNotifications
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
    static func applyEnableFromSettings(onBlocked: @escaping () -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                AppLogger.track("notifications_permission_result", properties: ["granted": granted])
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
