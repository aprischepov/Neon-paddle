import Foundation
enum PushPrePromptStorage {
    private static let fullAcceptKey = "push.prePrompt.notificationsFullyAccepted"
    private static let blockUntilKey = "push.prePrompt.blockUntil"
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
    static var blockPrePromptUntil: Date? {
        get { defaults.object(forKey: blockUntilKey) as? Date }
        set {
            if let newValue { defaults.set(newValue, forKey: blockUntilKey) }
            else { defaults.removeObject(forKey: blockUntilKey) }
        }
    }
    static func shouldPresentCustomPrePrompt(now: Date = Date()) -> Bool {
        if notificationsFullyAccepted { return false }
        if permanentDeclineAfterSystemPrompt { return false }
        if let until = blockPrePromptUntil, until > now { return false }
        return true
    }
    static func markFullyAccepted() {
        notificationsFullyAccepted = true
        blockPrePromptUntil = nil
        permanentDeclineAfterSystemPrompt = false
    }
    static func blockForThreeDays(from now: Date = Date()) {
        blockPrePromptUntil = Calendar.current.date(byAdding: .day, value: 3, to: now)
    }
    static func markPermanentDeclineAfterSystemDeny() {
        permanentDeclineAfterSystemPrompt = true
        blockPrePromptUntil = nil
    }
}
