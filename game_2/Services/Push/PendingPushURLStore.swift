import Foundation
enum PendingPushURLStore {
    private static let urlKey       = "PendingPushURL.v1.url"
    private static let timestampKey = "PendingPushURL.v1.ts"
    private static let ttl: TimeInterval = 10 * 60
    static var pendingURLString: String? {
        get {
            guard
                let ts = UserDefaults.standard.object(forKey: timestampKey) as? TimeInterval,
                Date().timeIntervalSince1970 - ts < ttl,
                let value = UserDefaults.standard.string(forKey: urlKey),
                !value.isEmpty
            else {
                _clear()
                return nil
            }
            return value
        }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: urlKey)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timestampKey)
            } else {
                _clear()
            }
        }
    }
    static var hasPendingURL: Bool {
        pendingURLString != nil
    }
    @discardableResult
    static func consumePending() -> String? {
        let v = pendingURLString
        _clear()
        return v
    }
    private static func _clear() {
        UserDefaults.standard.removeObject(forKey: urlKey)
        UserDefaults.standard.removeObject(forKey: timestampKey)
    }
}
