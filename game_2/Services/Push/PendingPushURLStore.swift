import Foundation

/// Одноразовая ссылка из tap по push **только в памяти процесса** (не UserDefaults, не `RemoteConfigStore`).
/// Следующий холодный старт загружает URL из ответа конфига.
enum PendingPushURLStore {
    private static var inMemoryPending: String?

    static var pendingURLString: String? {
        get { inMemoryPending }
        set {
            if let newValue, !newValue.isEmpty { inMemoryPending = newValue }
            else { inMemoryPending = nil }
        }
    }

    @discardableResult
    static func consumePending() -> String? {
        let v = inMemoryPending
        inMemoryPending = nil
        return v
    }
}
