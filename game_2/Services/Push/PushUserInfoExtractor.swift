import Foundation
enum PushUserInfoExtractor {
    static func urlString(from userInfo: [AnyHashable: Any]) -> String? {
        if let s = validURL(userInfo["url"]) { return s }
        if let data = userInfo["data"] as? [String: Any],
           let s = validURL(data["url"]) { return s }
        if let s = validURL(userInfo["data.url"]) { return s }
        return nil
    }
    static func imageURLString(from userInfo: [AnyHashable: Any]) -> String? {
        PushPayloadParser.imageURLString(from: userInfo)
    }
    private static func validURL(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty,
              let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return s
    }
}
