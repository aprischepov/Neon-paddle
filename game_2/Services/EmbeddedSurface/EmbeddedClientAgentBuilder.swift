import UIKit
import WebKit
enum EmbeddedClientAgentBuilder {
    private static var cachedMobileSegment: String?
    private static let mobileLock = NSLock()
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
        } ?? AppConstants.StoreListing.appStoreNumericId
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
