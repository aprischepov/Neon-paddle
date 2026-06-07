import Foundation
enum RemoteConfigStore {
    private static let urlKey = "RemoteConfig.savedURL"
    private static let expiresKey = "RemoteConfig.savedExpiresUnix"
    static var savedURLString: String? {
        get { UserDefaults.standard.string(forKey: urlKey) }
        set {
            if let newValue { UserDefaults.standard.set(newValue, forKey: urlKey) }
            else { UserDefaults.standard.removeObject(forKey: urlKey) }
        }
    }
    static var savedExpiresUnix: Int? {
        get {
            guard UserDefaults.standard.object(forKey: expiresKey) != nil else { return nil }
            return UserDefaults.standard.integer(forKey: expiresKey)
        }
        set {
            if let newValue { UserDefaults.standard.set(newValue, forKey: expiresKey) }
            else { UserDefaults.standard.removeObject(forKey: expiresKey) }
        }
    }
    static func clear() {
        savedURLString = nil
        savedExpiresUnix = nil
    }
    static var shouldRefreshFromEndpoint: Bool {
        guard let expires = savedExpiresUnix else { return true }
        return Date().timeIntervalSince1970 >= TimeInterval(expires)
    }
}
