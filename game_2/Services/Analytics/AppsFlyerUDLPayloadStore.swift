import Foundation
enum AppsFlyerUDLPayloadStore {
    private static let userDefaultsKey = "AppsFlyerUDLPayload.v1"
    private static var memoryCache: [String: Any]?
    static func save(_ payload: [String: Any]) {
        memoryCache = payload
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [])
        else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
    static func currentPayload() -> [String: Any]? {
        if let memoryCache { return memoryCache }
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
    static func clear() {
        memoryCache = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
extension Notification.Name {
    static let appsFlyerUDLPayloadDidUpdate = Notification.Name("appsFlyerUDLPayloadDidUpdate")
}
