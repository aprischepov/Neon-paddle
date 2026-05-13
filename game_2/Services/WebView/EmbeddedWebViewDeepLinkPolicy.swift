import UIKit
import WebKit

/// Диплинки и прочие не-http(s) ссылки: не грузим их в `WKWebView` (иначе ошибка), отдаём системе через `UIApplication.open`.
/// При сбое загрузки из‑за «плохого» URL — при возможности `goBack()`, чтобы не оставаться на экране ошибки.
@MainActor
enum EmbeddedWebViewDeepLinkPolicy {

    private static let webContentSchemes: Set<String> = [
        "http", "https", "about", "blob", "javascript", "data",
    ]

    static func isWebContentNavigationURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return webContentSchemes.contains(scheme)
    }

    /// URL запроса основного фрейма, который будет загружен внутри WebView (http/https и т.д.); для трекинга цепочки редиректов при `httpTooManyRedirects`.
    static func mainFrameWebRequestURLIfLoadingInWebView(_ navigationAction: WKNavigationAction) -> URL? {
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        guard isMainFrame else { return nil }
        guard let url = navigationAction.request.url,
              isWebContentNavigationURL(url),
              url.scheme?.lowercased() != "file" else { return nil }
        return url
    }

    /// Для `decidePolicyFor`: разрешает только обычный веб-контент; остальное открывает снаружи и отменяет навигацию в WebView.
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

        if isWebContentNavigationURL(url) {
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

    /// Для `createWebViewWith` / подобных случаев: если URL не для WebView — открыть снаружи и вернуть `true` (в WebView не грузить).
    @discardableResult
    static func tryHandleNonWebRequestExternally(_ request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        if isWebContentNavigationURL(url) {
            return false
        }
        if url.scheme?.lowercased() == "file" {
            return true
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
    }

    static func recoverWithGoBackIfUnsupportedURL(webView: WKWebView, error: Error) {
        guard shouldTreatAsUnsupportedOrBadURL(error), webView.canGoBack else { return }
        webView.goBack()
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
