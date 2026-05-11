import AppTrackingTransparency

/// Запрос разрешения на отслеживание (ATT). Без `NSUserTrackingUsageDescription` в Info.plist приложение упадёт при вызове.
enum AppTrackingService {

    /// Сначала системный диалог ATT (на iOS 14+, если доступно), затем `completion` на главном потоке.
    /// Повторные вызовы `requestTrackingAuthorization` не показывают диалог снова — completion приходит с текущим статусом.
    static func requestAuthorizationThen(completion: @escaping () -> Void) {
        if #available(iOS 14.0, *) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async(execute: completion)
            }
        } else {
            completion()
        }
    }
}
