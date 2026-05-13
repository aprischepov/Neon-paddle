import Foundation

/// Обработка `NSURLErrorHTTPTooManyRedirects` / ERR_TOO_MANY_REDIRECTS: однократная перезагрузка по последнему URL цепочки редиректов (или `NSURLErrorFailingURL…` из ошибки).
enum WKWebViewRedirectLoopRecovery {
    final class Session {
        private(set) var lastProvisionalRedirectURL: URL?
        /// Последний URL основного фрейма из `decidePolicyFor` (редиректы тоже приходят сюда); WK не всегда даёт `webView.url` и ключи в `NSError` при `-1007`.
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

        /// Вызывать для основного фрейма при навигации, которую WebView реально загружает (http/https и т.д., не внешние схемы).
        func noteMainFrameProvisionalURL(_ url: URL?) {
            guard let url else { return }
            lastMainFramePolicyURL = url
        }

        func noteServerRedirect(targetURL: URL?) {
            lastProvisionalRedirectURL = targetURL
        }

        /// Если нужно продолжить загрузку после слишком длинной цепочки редиректов — вернуть запрос; иначе `nil`.
        func recoveryRequestIfNeeded(for error: Error, fallbackURL: URL? = nil) -> URLRequest? {
            guard Self.isTooManyRedirects(error) else { return nil }
            guard !recoveryLoadIssued else { return nil }
            let url = lastProvisionalRedirectURL
                ?? lastMainFramePolicyURL
                ?? Self.failingURL(from: error)
                ?? fallbackURL
            guard let url else { return nil }
            recoveryLoadIssued = true
            isRecoveryNavigation = true
            return URLRequest(url: url)
        }

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
