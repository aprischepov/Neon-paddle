import UIKit
import WebKit

/// Обработка `NSURLErrorHTTPTooManyRedirects` (-1007): однократная перезагрузка после ручного разворачивания цепочки 3xx вне WebKit.
enum WKWebViewRedirectLoopRecovery {
    private static func isTooManyRedirects(_ error: Error) -> Bool {
        if let urlError = error as? URLError, urlError.code == .httpTooManyRedirects {
            return true
        }
        var current: NSError? = error as NSError
        while let ns = current {
            if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorHTTPTooManyRedirects {
                return true
            }
            current = ns.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }

    private static func failingURL(from error: Error) -> URL? {
        if let urlError = error as? URLError, let url = urlError.failureURL {
            return url
        }
        var current: NSError? = error as NSError
        while let ns = current {
            if let url = ns.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
                return url
            }
            let stringKeys = [
                NSURLErrorFailingURLStringErrorKey,
                "NSErrorFailingURLStringKey",
                "WKErrorFailingURLStringKey",
            ]
            for key in stringKeys {
                if let s = ns.userInfo[key] as? String, let url = URL(string: s) {
                    return url
                }
            }
            current = ns.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return nil
    }

    final class Session {
        private(set) var lastProvisionalRedirectURL: URL?
        /// Последний URL основного фрейма из `decidePolicyFor` (редиректы тоже приходят сюда).
        private var lastMainFramePolicyURL: URL?
        private var recoveryLoadIssued = false
        private var isRecoveryNavigation = false

        func noteProvisionalNavigationStarted() {
            lastProvisionalRedirectURL = nil
            if !isRecoveryNavigation {
                recoveryLoadIssued = false
            }
            isRecoveryNavigation = false
        }

        func noteMainFrameProvisionalURL(_ url: URL?) {
            guard let url else { return }
            lastMainFramePolicyURL = url
        }

        func noteServerRedirect(targetURL: URL?) {
            lastProvisionalRedirectURL = targetURL
        }

        var hasIssuedRecoveryLoad: Bool {
            recoveryLoadIssued
        }

        func recoveryCandidateURL(for error: Error, fallbackURL: URL?) -> URL? {
            lastProvisionalRedirectURL
                ?? lastMainFramePolicyURL
                ?? WKWebViewRedirectLoopRecovery.failingURL(from: error)
                ?? fallbackURL
        }

        func markRecoveryLoadIssuedForNextNavigation() {
            recoveryLoadIssued = true
            isRecoveryNavigation = true
        }
    }

    /// Одна попытка: развернуть 3xx через `URLSession`, затем `load` в WebView.
    @MainActor
    static func handleTooManyRedirectsRecoveryIfNeeded(
        webView: WKWebView,
        error: Error,
        session: Session,
        fallbackURL: URL?
    ) async -> Bool {
        guard isTooManyRedirects(error) else { return false }
        guard !session.hasIssuedRecoveryLoad else { return false }
        guard let candidate = session.recoveryCandidateURL(for: error, fallbackURL: fallbackURL) else { return false }
        session.markRecoveryLoadIssuedForNextNavigation()
        let ua = webView.customUserAgent ?? WebViewUserAgentBuilder.standardEmbeddedUserAgent()
        let urlToLoad: URL
        do {
            urlToLoad = try await HTTPRedirectChainResolver.resolve(
                byFollowingRedirectsFrom: candidate,
                maxHops: 128,
                userAgent: ua
            )
        } catch {
            urlToLoad = candidate
        }
        webView.load(URLRequest(url: urlToLoad))
        return true
    }
}

private extension URLError {
    var failureURL: URL? {
        if let u = userInfo[NSURLErrorFailingURLErrorKey] as? URL {
            return u
        }
        if let s = userInfo[NSURLErrorFailingURLStringErrorKey] as? String {
            return URL(string: s)
        }
        return nil
    }
}
