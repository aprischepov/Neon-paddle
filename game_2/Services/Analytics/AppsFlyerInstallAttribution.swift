import Foundation

/// Разбор полей install conversion и одноразовый отложенный повтор запроса при «раннем» Organic на первом запуске.
enum AppsFlyerInstallAttribution {

    /// Пауза перед повторным стартом SDK, чтобы подтянулась отложенная атрибуция.
    static let deferredInstallConversionRefreshDelay: TimeInterval = 5

    private static let deferredRefreshCompletedKey = "AppsFlyerDeferredInstallConversionRefresh.v1"

    static var isDeferredInstallConversionRefreshCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: deferredRefreshCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: deferredRefreshCompletedKey) }
    }

    static func afStatus(from raw: [AnyHashable: Any]) -> String? {
        guard let value = raw["af_status"] else { return nil }
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isOrganicAFStatus(_ status: String?) -> Bool {
        guard let status else { return false }
        return status.caseInsensitiveCompare("Organic") == .orderedSame
    }

    /// `is_first_launch` в payload AppsFlyer (часто `1` / `true` на первом открытии).
    static func isFirstLaunch(from raw: [AnyHashable: Any]) -> Bool {
        guard let value = raw["is_first_launch"] else { return false }
        if let bool = value as? Bool { return bool }
        if let int = value as? Int { return int != 0 }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            let lower = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return lower == "1" || lower == "true" || lower == "yes"
        }
        return false
    }

    /// Нужен ли отложенный повтор: первый запуск, Organic, повтор ещё не выполняли.
    static func shouldScheduleDeferredInstallConversionRefresh(afterReceiving raw: [AnyHashable: Any]) -> Bool {
        guard !isDeferredInstallConversionRefreshCompleted else { return false }
        guard isFirstLaunch(from: raw) else { return false }
        return isOrganicAFStatus(afStatus(from: raw))
    }
}
