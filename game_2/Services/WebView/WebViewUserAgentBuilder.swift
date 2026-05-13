import UIKit
import WebKit

/// Сборка User-Agent в духе Mobile Safari: актуальное устройство и iOS, без `wv` и прочих маркеров WebView; суффикс `appid/… appname/…`.
enum WebViewUserAgentBuilder {

    private static var cachedMobileSegment: String?
    private static let mobileLock = NSLock()

    /// Строка для `WKWebView.customUserAgent` (основной оффер, пуш-лендинг, политики).
    static func standardEmbeddedUserAgent() -> String {
        let os = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        let devicePart: String
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            devicePart = "iPad; CPU OS \(os) like Mac OS X"
        default:
            devicePart = "iPhone; CPU iPhone OS \(os) like Mac OS X"
        }

        let plistId = Bundle.main.object(forInfoDictionaryKey: "AppStoreAppleAppID") as? String
        let appId = plistId.flatMap { id -> String? in
            let t = id.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        } ?? AppConstants.WebBrowsing.appStoreNumericId

        let appToken = appNameToken()
        let mobile = mobileSegmentFromSystemWebKit()

        return "Mozilla/5.0 (\(devicePart)) AppleWebKit/605.1.15 (KHTML, like Gecko) \(mobile) appid/\(appId) appname/\(appToken)"
    }

    private static func appNameToken() -> String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Application"
        return raw.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    /// Сегмент `Mobile/…` как у системного WebKit (без явной подписи embedded WebView).
    private static func mobileSegmentFromSystemWebKit() -> String {
        mobileLock.lock()
        if let cachedMobileSegment {
            mobileLock.unlock()
            return cachedMobileSegment
        }
        mobileLock.unlock()

        let probe = WKWebView(frame: .zero)
        let defaultUA = probe.value(forKey: "userAgent") as? String ?? ""
        let token: String
        if let range = defaultUA.range(of: "Mobile/[0-9A-Za-z]+", options: .regularExpression) {
            token = String(defaultUA[range])
        } else {
            token = "Mobile/15E148"
        }

        mobileLock.lock()
        cachedMobileSegment = token
        mobileLock.unlock()
        return token
    }
}
