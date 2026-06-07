import Foundation
enum AppStartupSettings {
    private static let resolvedModeKey = "AppStartup.ResolvedMode.v1"
    enum ResolvedMode: String {
        case inlineSurface = "inline_surface"
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
    static var isFirstLaunchFlowPending: Bool {
        resolvedMode == nil
    }
    static func setResolved(_ mode: ResolvedMode) {
        resolvedMode = mode
    }
}
extension Notification.Name {
    static let appStartupRoutingReady = Notification.Name("appStartupRoutingReady")
    static let appStartupConfigTransportFailed = Notification.Name("appStartupConfigTransportFailed")
    static let connectivityDidChange = Notification.Name("connectivityDidChange")
}
