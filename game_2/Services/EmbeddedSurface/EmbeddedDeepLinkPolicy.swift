import UIKit
import WebKit
@MainActor
enum EmbeddedDeepLinkPolicy {
    private static let inlineContentSchemes: Set<String> = [
        "http", "https", "about", "blob", "javascript", "data",
    ]
    static func isInlineContentNavigationURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return inlineContentSchemes.contains(scheme)
    }
    static func mainFrameRequestURLIfLoadingInline(_ navigationAction: WKNavigationAction) -> URL? {
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        guard isMainFrame else { return nil }
        guard let url = navigationAction.request.url,
              isInlineContentNavigationURL(url),
              url.scheme?.lowercased() != "file" else { return nil }
        return url
    }
    static func decidePolicyForNavigationAction(
        _ navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        preferences.allowsContentJavaScript = true
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow, preferences)
            return
        }
        if isInlineContentNavigationURL(url) {
            decisionHandler(.allow, preferences)
            return
        }
        if url.scheme?.lowercased() == "file" {
            decisionHandler(.cancel, preferences)
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        decisionHandler(.cancel, preferences)
    }
    @discardableResult
    static func tryHandleExternalRequestOutside(_ request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        if isInlineContentNavigationURL(url) {
            return false
        }
        if url.scheme?.lowercased() == "file" {
            return true
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
    }
    static func recoverWithGoBackIfUnsupportedURL(surfaceView: WKWebView, error: Error) {
        guard shouldTreatAsUnsupportedOrBadURL(error), surfaceView.canGoBack else { return }
        surfaceView.goBack()
    }
    private static func shouldTreatAsUnsupportedOrBadURL(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .unsupportedURL, .badURL:
                return true
            default:
                break
            }
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain,
           ns.code == NSURLErrorUnsupportedURL || ns.code == NSURLErrorBadURL {
            return true
        }
        return false
    }
}
