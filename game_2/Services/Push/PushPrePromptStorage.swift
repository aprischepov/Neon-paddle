import Foundation

/// Состояние кастомного пре-промпта уведомлений (режим WebView).
enum PushPrePromptStorage {
    private static let fullAcceptKey = "push.prePrompt.notificationsFullyAccepted"
    private static let blockUntilKey = "push.prePrompt.blockCustomOffersUntil"
    /// После отказа в **системном** диалоге (после «Разрешить» на кастомном экране) — кастомный экран больше не показываем; системный запрос iOS повторно не покажет.
    private static let permanentAfterSystemDenyKey = "push.prePrompt.permanentAfterSystemDeny"

    private static let defaults = UserDefaults.standard

    static var notificationsFullyAccepted: Bool {
        get { defaults.bool(forKey: fullAcceptKey) }
        set { defaults.set(newValue, forKey: fullAcceptKey) }
    }

    static var permanentDeclineAfterSystemPrompt: Bool {
        get { defaults.bool(forKey: permanentAfterSystemDenyKey) }
        set { defaults.set(newValue, forKey: permanentAfterSystemDenyKey) }
    }

    static var blockCustomOffersUntil: Date? {
        get { defaults.object(forKey: blockUntilKey) as? Date }
        set {
            if let newValue { defaults.set(newValue, forKey: blockUntilKey) }
            else { defaults.removeObject(forKey: blockUntilKey) }
        }
    }

    /// Показывать ли кастомный экран (только при `notDetermined` у системы).
    static func shouldPresentCustomPrePrompt(now: Date = Date()) -> Bool {
        if notificationsFullyAccepted { return false }
        if permanentDeclineAfterSystemPrompt { return false }
        if let until = blockCustomOffersUntil, until > now { return false }
        return true
    }

    static func markFullyAccepted() {
        notificationsFullyAccepted = true
        blockCustomOffersUntil = nil
        permanentDeclineAfterSystemPrompt = false
    }

    /// «Не сейчас» на кастомном экране — повтор кастомного экрана не раньше чем через 3 дня.
    static func blockForThreeDays(from now: Date = Date()) {
        blockCustomOffersUntil = Calendar.current.date(byAdding: .day, value: 3, to: now)
    }

    /// Отказ в системном запросе после согласия на кастомном экране — кастомный экран и повторный системный запрос из приложения недоступны.
    static func markPermanentDeclineAfterSystemDeny() {
        permanentDeclineAfterSystemPrompt = true
        blockCustomOffersUntil = nil
    }
}
