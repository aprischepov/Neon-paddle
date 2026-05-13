import Foundation

/// Локальное сохранение последнего успешного conversion payload между запусками.
enum AppsFlyerConversionStore {
    private static let userDefaultsKey = "AppsFlyerConversionPayload.v1"

    static func save(_ payload: [String: Any]) {
        guard let data = AppsFlyerConversionPayload.jsonData(from: payload) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    static func load() -> [String: Any]? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        return AppsFlyerConversionPayload.dictionary(from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
