import Foundation

/// Обработка `NSURLErrorHTTPTooManyRedirects` / ERR_TOO_MANY_REDIRECTS: однократная перезагрузка по последнему URL цепочки редиректов (или `NSURLErrorFailingURL…` из ошибки).
enum WKWebViewRedirectLoopRecovery {
    final class Session {
        private(set) var lastProvisionalRedirectURL: URL?
        private var recoveryLoadIssued = false
        private var isRecoveryNavigation = false

        func noteProvisionalNavigationStarted() {
            lastProvisionalRedirectURL = nil
            if !isRecoveryNavigation {
                recoveryLoadIssued = false
            }
            isRecoveryNavigation = false
        }

        func noteServerRedirect(targetURL: URL?) {
            lastProvisionalRedirectURL = targetURL
        }

        /// Если нужно продолжить загрузку после слишком длинной цепочки редиректов — вернуть запрос; иначе `nil`.
        func recoveryRequestIfNeeded(for error: Error) -> URLRequest? {
            guard Self.isTooManyRedirects(error) else { return nil }
            guard !recoveryLoadIssued else { return nil }
            guard let url = lastProvisionalRedirectURL ?? Self.failingURL(from: error) else { return nil }
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
                if let s = ns.userInfo[NSURLErrorFailingURLStringErrorKey] as? String, let url = URL(string: s) {
                    return url
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
