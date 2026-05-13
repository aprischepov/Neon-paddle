import Foundation

/// Режим после первого успешного решения по конфигу. `nil` — первый запуск ещё не завершён (1.1 / 1.2 / 1.3).
enum AppStartupSettings {
    private static let resolvedModeKey = "AppStartup.ResolvedMode.v1"

    enum ResolvedMode: String {
        case webView = "webview"
        case wrapper = "wrapper"
    }

    static var resolvedMode: ResolvedMode? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: resolvedModeKey) else { return nil }
            return ResolvedMode(rawValue: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.rawValue, forKey: resolvedModeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: resolvedModeKey)
            }
        }
    }

    /// Первый запуск: режим ещё не зафиксирован по ответу сервера (п. 1.1 / 1.2) или ожидание сети (1.3).
    static var isFirstLaunchFlowPending: Bool {
        resolvedMode == nil
    }

    static func setResolved(_ mode: ResolvedMode) {
        resolvedMode = mode
    }
}

extension Notification.Name {
    /// Режим записан в `AppStartupSettings`; UI может перейти к WebView или обёртке.
    static let appStartupRoutingReady = Notification.Name("appStartupRoutingReady")

    /// Запрос конфига не дошёл до сервера (транспорт / DNS и т.д.); режим **не** меняется.
    static let appStartupConfigTransportFailed = Notification.Name("appStartupConfigTransportFailed")

    static let connectivityDidChange = Notification.Name("connectivityDidChange")
}
